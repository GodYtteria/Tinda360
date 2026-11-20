import argparse
import json
import os
import sys
import collections
import re

import torch

from model import ModelConfig, YtteriaDragon
import build_dataset


SYSTEM_PROMPT = (
    "Ikaw si Yumi, AI assistant ng sari-sari store. "
    "Sumagot sa Taglish. Gumamit ng tools para kunin ang data mula sa database. "
    "Huwag mag-imbento ng datos — always call a tool first. "
    "Maging friendly, concise, at helpful."
)


def parse_args():
    parser = argparse.ArgumentParser(description="Evaluate YtteriaDragon tool-calling model")
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--tokenizer", default="tokenizer.json")
    parser.add_argument("--test-frac", type=float, default=0.1)
    parser.add_argument("--device", default="auto", choices=["auto", "cuda", "cpu", "xpu"])
    parser.add_argument("--interactive", action="store_true")
    parser.add_argument("--pipe", action="store_true")
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--max-new", type=int, default=256)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--top-k-report", type=int, default=10)
    parser.add_argument("--no-tools", action="store_true")
    return parser.parse_args()


def get_device(choice):
    if choice != "auto":
        return torch.device(choice)
    if torch.cuda.is_available():
        return torch.device("cuda")
    if hasattr(torch, "xpu") and torch.xpu.is_available():
        return torch.device("xpu")
    return torch.device("cpu")


def load_model(checkpoint_path, device):
    state = torch.load(checkpoint_path, map_location=device, weights_only=False)
    config = ModelConfig(**state["config"])
    model = YtteriaDragon(config).to(device)
    model.load_state_dict(state["model"])
    model.eval()
    step = state.get("step", "?")
    val_loss = state.get("best_val_loss", "?")
    print(f"  Model loaded: step={step}, val_loss={val_loss}", file=sys.stderr)
    print(f"  Params: {model.num_params():,} total, {model.num_active_params():,} active", file=sys.stderr)
    return model, config


def load_tokenizer(path):
    from tokenizers import Tokenizer
    tokenizer = Tokenizer.from_file(path)
    print(f"  Tokenizer: {path} (vocab={tokenizer.get_vocab_size()})", file=sys.stderr)
    return tokenizer


def load_all_tools():
    fname = "tinda360_tool_calling.jsonl"
    if not os.path.exists(fname):
        return []
    with open(fname) as file_handle:
        first_line = json.loads(file_handle.readline())
        tools = first_line.get("tools")
        if isinstance(tools, list):
            return tools
    return []


def format_all_tools(tools):
    lines = []
    for tool_entry in tools:
        function_def = tool_entry["function"]
        params = function_def.get("parameters", {}).get("properties", {})
        param_str = ", ".join(
            f"{key}: {val.get('type', '?')}"
            for key, val in params.items()
            if key not in build_dataset.ENTITY_ARGUMENTS
        )
        lines.append(f"{function_def['name']}({param_str})")
    return "\n".join(lines)


def build_chatml_prompt(user_query, tools_text=None):
    parts = []
    parts.append(f"<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>")
    if tools_text:
        parts.append(f"<|im_start|>system\nTools:\n{tools_text}<|im_end|>")
    parts.append(f"<|im_start|>user\n{user_query}<|im_end|>")
    parts.append("<|im_start|>assistant\n")
    return "\n".join(parts)


def generate_response(model, tokenizer, prompt, max_new=256, temperature=0.0):
    enc = tokenizer.encode(prompt)
    ids = enc.ids
    eos = tokenizer.token_to_id("[EOS]")
    if ids and ids[-1] == eos:
        ids = ids[:-1]

    im_end = tokenizer.token_to_id("<|im_end|>")
    stop = set()
    if eos is not None:
        stop.add(eos)
    if im_end is not None:
        stop.add(im_end)

    out_ids = model.generate(ids, max_new=max_new, stop=stop, temperature=temperature)
    return tokenizer.decode(out_ids, skip_special_tokens=False)


def extract_tool_call(output_str):
    match = re.search(r"<tool_call>(.*?)</tool_call>", output_str, re.DOTALL)
    if match:
        try:
            parsed = json.loads(match.group(1).strip())
            return parsed.get("name", ""), parsed.get("arguments", {})
        except (json.JSONDecodeError, TypeError):
            pass
    return None, None


def clean_output(output_str):
    output_str = re.sub(r"<\|im_start\|>\w*\n?", "", output_str)
    output_str = output_str.replace("<|im_end|>", "")
    return output_str.strip()


def _parse_jsonl_example(line):
    record = json.loads(line)
    msgs = record.get("messages", [])
    user_msg = next((msg["content"] for msg in msgs if msg["role"] == "user"), None)
    if not user_msg:
        return None
    expected_tool = None
    expected_text = None
    for msg in msgs:
        if msg["role"] == "assistant":
            calls = msg.get("tool_calls", [])
            if calls:
                expected_tool = calls[0]["name"]
            elif msg.get("content"):
                expected_text = msg["content"][:200]
            break
    return {
        "query": user_msg,
        "expected_tool": expected_tool,
        "expected_text": expected_text,
        "source": record.get("source", ""),
    }


def load_test_data(test_frac=0.1, seed=42):
    fname = "tinda360_tool_calling.jsonl"
    if not os.path.exists(fname):
        print("  No tool_calling.jsonl found", file=sys.stderr)
        return []

    all_examples = []
    with open(fname) as file_handle:
        for line in file_handle:
            example = _parse_jsonl_example(line)
            if example:
                all_examples.append(example)

    import random
    rng = random.Random(seed)
    rng.shuffle(all_examples)
    n_test = max(1, int(len(all_examples) * test_frac))
    examples = all_examples[:n_test]
    print(f"  Test split: {n_test} from {len(all_examples)} total", file=sys.stderr)
    return examples


def _score_one_example(example, model, tokenizer, tools_text, temperature, max_new,
                        per_tool_correct, per_tool_total, confusion, errors,
                        correct_tool_count, total_tool_count, correct_notool_count, total_notool_count):
    prompt = build_chatml_prompt(example["query"], tools_text)
    generated = generate_response(model, tokenizer, prompt, max_new, temperature)
    pred_tool, _ = extract_tool_call(generated)

    if example["expected_tool"]:
        total_tool_count += 1
        per_tool_total[example["expected_tool"]] += 1
        if pred_tool == example["expected_tool"]:
            correct_tool_count += 1
            per_tool_correct[example["expected_tool"]] += 1
        else:
            confusion[(example["expected_tool"], pred_tool or "(none)")] += 1
            errors.append({
                "query": example["query"],
                "expected": example["expected_tool"],
                "predicted": pred_tool or "(no tool call)",
                "raw": clean_output(generated)[:150],
                "source": example["source"],
            })
    else:
        total_notool_count += 1
        if not pred_tool:
            correct_notool_count += 1
        else:
            errors.append({
                "query": example["query"],
                "expected": "(no tool)",
                "predicted": pred_tool,
                "raw": clean_output(generated)[:150],
                "source": example["source"],
            })

    return correct_tool_count, total_tool_count, correct_notool_count, total_notool_count


def evaluate_batch(model, tokenizer, examples, tools_text, temperature=0.0, max_new=256):
    per_tool_correct = collections.Counter()
    per_tool_total = collections.Counter()
    confusion = collections.Counter()
    errors = []
    correct_tool = total_tool = correct_notool = total_notool = 0

    for index, example in enumerate(examples):
        correct_tool, total_tool, correct_notool, total_notool = _score_one_example(
            example, model, tokenizer, tools_text, temperature, max_new,
            per_tool_correct, per_tool_total, confusion, errors,
            correct_tool, total_tool, correct_notool, total_notool,
        )
        if (index + 1) % 20 == 0:
            tool_acc = correct_tool / max(total_tool, 1)
            print(f"    {index+1}/{len(examples)} tool_acc={tool_acc:.1%}", file=sys.stderr)

    total = total_tool + total_notool
    correct = correct_tool + correct_notool
    return {
        "total": total,
        "correct": correct,
        "accuracy": correct / max(total, 1),
        "tool_total": total_tool,
        "tool_correct": correct_tool,
        "tool_accuracy": correct_tool / max(total_tool, 1),
        "notool_total": total_notool,
        "notool_correct": correct_notool,
        "notool_accuracy": correct_notool / max(total_notool, 1),
        "per_tool_correct": dict(per_tool_correct),
        "per_tool_total": dict(per_tool_total),
        "confusion": confusion,
        "errors": errors,
    }


def _print_per_tool_table(results):
    if not results["per_tool_total"]:
        return
    print(f"  {'Tool':<30} {'Correct':>7} {'Total':>7} {'Acc':>7}")
    print(f"  {'-'*53}")
    for tool in sorted(results["per_tool_total"].keys()):
        total_count = results["per_tool_total"][tool]
        correct_count = results["per_tool_correct"].get(tool, 0)
        acc = correct_count / max(total_count, 1)
        marker = " !!!" if acc < 0.5 else (" !" if acc < 0.8 else "")
        print(f"  {tool:<30} {correct_count:>7} {total_count:>7} {acc:>6.0%}{marker}")


def _print_confusion(results, top_k):
    if not results["confusion"]:
        return
    print(f"\n  Top {top_k} confused pairs:")
    sorted_conf = sorted(results["confusion"].items(), key=lambda pair: -pair[1])
    for (expected, predicted), count in sorted_conf[:top_k]:
        print(f"    {expected} -> {predicted}: {count}x")


def _print_errors(results):
    if not results["errors"]:
        return
    print(f"\n  Sample errors (first 15):")
    for err in results["errors"][:15]:
        print(f"    Q: {err['query'][:60]}")
        print(f"    Expected: {err['expected']}, Got: {err['predicted']}")
        print(f"    Raw: {err['raw'][:100]}")
        print(f"    Src: {err['source']}")
        print()


def print_report(results, top_k=10):
    print(f"\n{'='*60}")
    print(f"  EVALUATION REPORT")
    print(f"{'='*60}")
    print(f"  Overall:  {results['correct']}/{results['total']} = {results['accuracy']:.1%}")
    print(f"  Tool sel: {results['tool_correct']}/{results['tool_total']} = {results['tool_accuracy']:.1%}")
    print(f"  No-tool:  {results['notool_correct']}/{results['notool_total']} = {results['notool_accuracy']:.1%}")
    print()
    _print_per_tool_table(results)
    _print_confusion(results, top_k)
    _print_errors(results)


def interactive_mode(model, tokenizer, tools_text, temperature=0.0, max_new=256):
    print("\n  Interactive mode (type 'quit' to exit)")
    print("  " + "-" * 50, file=sys.stderr)
    while True:
        try:
            query = input("\n  You: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if query.lower() in ("quit", "exit", "q"):
            break
        if not query:
            continue

        prompt = build_chatml_prompt(query, tools_text)
        response = generate_response(model, tokenizer, prompt, max_new, temperature)
        cleaned = clean_output(response)
        tool_name, tool_args = extract_tool_call(response)

        print(f"  Yumi: {cleaned}")
        if tool_name:
            print(f"  [tool: {tool_name}({json.dumps(tool_args, ensure_ascii=False)})]")


def pipe_mode(model, tokenizer, tools_text, temperature=0.0, max_new=256):
    for line in sys.stdin:
        query = line.strip()
        if not query:
            continue
        prompt = build_chatml_prompt(query, tools_text)
        response = generate_response(model, tokenizer, prompt, max_new, temperature)
        tool_name, tool_args = extract_tool_call(response)
        result = {
            "query": query,
            "tool": tool_name,
            "args": tool_args,
            "response": clean_output(response),
        }
        print(json.dumps(result, ensure_ascii=False))
        sys.stdout.flush()


def _load_tools_text(args):
    if args.no_tools:
        return None
    tools = load_all_tools()
    if not tools:
        return None
    tools_text = format_all_tools(tools)
    print(f"  Tools: {len(tools)} loaded", file=sys.stderr)
    return tools_text


def _save_results(results, checkpoint_path):
    out_path = os.path.join(os.path.dirname(checkpoint_path), "eval_results.json")
    serializable = {**results}
    serializable["confusion"] = {f"{pair[0]} -> {pair[1]}": count for pair, count in results["confusion"].items()}
    with open(out_path, "w") as file_handle:
        json.dump(serializable, file_handle, indent=2, ensure_ascii=False)
    print(f"\n  Results saved: {out_path}", file=sys.stderr)


def main():
    args = parse_args()
    torch.manual_seed(args.seed)
    device = get_device(args.device)
    print(f"Device: {device}", file=sys.stderr)

    model, config = load_model(args.checkpoint, device)
    tokenizer = load_tokenizer(args.tokenizer)
    tools_text = _load_tools_text(args)

    if args.interactive:
        interactive_mode(model, tokenizer, tools_text, args.temperature, args.max_new)
        return

    if args.pipe:
        pipe_mode(model, tokenizer, tools_text, args.temperature, args.max_new)
        return

    examples = load_test_data(args.test_frac, args.seed)
    if not examples:
        print("  No test data found.", file=sys.stderr)
        return

    print(f"\n  Evaluating {len(examples)} examples...", file=sys.stderr)
    results = evaluate_batch(model, tokenizer, examples, tools_text, args.temperature, args.max_new)
    print_report(results, args.top_k_report)
    _save_results(results, args.checkpoint)


if __name__ == "__main__":
    main()
