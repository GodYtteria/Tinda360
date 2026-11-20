import argparse
import time

import torch

from model import ModelConfig, YtteriaDragon


def parse_args():
    parser = argparse.ArgumentParser(description="Benchmark YtteriaDragon")
    parser.add_argument("--checkpoint", default=None)
    parser.add_argument("--preset", default="50M-tinda360")
    parser.add_argument("--tokenizer", default="tokenizer.json")
    parser.add_argument("--device", default="auto")
    parser.add_argument("--context-lengths", type=int, nargs="+", default=[64, 128, 256, 512, 1024])
    parser.add_argument("--gen-tokens", type=int, default=64)
    parser.add_argument("--warmup-runs", type=int, default=3)
    parser.add_argument("--bench-runs", type=int, default=10)
    return parser.parse_args()


def get_device(choice):
    if choice != "auto":
        return torch.device(choice)
    if torch.cuda.is_available():
        return torch.device("cuda")
    if hasattr(torch, "xpu") and torch.xpu.is_available():
        return torch.device("xpu")
    return torch.device("cpu")


def _sync(device):
    if device.type == "cuda":
        torch.cuda.synchronize()


def bench_prefill(model, ids, device, runs=10):
    tokens = torch.tensor([ids], device=device)
    for _ in range(3):
        with torch.no_grad():
            model(tokens)
    _sync(device)

    times = []
    for _ in range(runs):
        _sync(device)
        start = time.perf_counter()
        with torch.no_grad():
            model(tokens)
        _sync(device)
        times.append(time.perf_counter() - start)
    return times


def bench_generate(model, prompt_ids, gen_tokens, device, runs=5):
    for _ in range(2):
        model.generate(prompt_ids, max_new=gen_tokens)

    times = []
    for _ in range(runs):
        _sync(device)
        start = time.perf_counter()
        out_ids = model.generate(prompt_ids, max_new=gen_tokens)
        _sync(device)
        times.append((time.perf_counter() - start, len(out_ids)))
    return times


def bench_compact(model, prompt_ids, gen_tokens, device):
    caches = [{} for _ in model.layers]
    tokens = torch.tensor([prompt_ids], device=device)
    with torch.no_grad():
        model(tokens, caches=caches, pos=0)

    before_bytes = model.cache_memory_bytes(caches)
    start = time.perf_counter()
    caches, evicted = model.auto_compact(caches)
    compact_duration = time.perf_counter() - start
    after_bytes = model.cache_memory_bytes(caches)
    return before_bytes, after_bytes, evicted, compact_duration


def _load_model(args, device):
    from model import PRESETS
    if args.checkpoint:
        state = torch.load(args.checkpoint, map_location=device, weights_only=False)
        config = ModelConfig(**state["config"])
        model = YtteriaDragon(config).to(device)
        model.load_state_dict(state["model"])
    else:
        config = ModelConfig(**PRESETS[args.preset].__dict__)
        model = YtteriaDragon(config).to(device)
    model.eval()
    return model, config


def _run_context_benchmarks(model, config, args, device):
    print(f"\n{'='*70}")
    print(f"{'Context':>8} {'Prefill ms':>12} {'tok/s prefill':>14} {'Gen tok/s':>12} {'Cache KB':>10}")
    print(f"{'='*70}")

    for context_len in args.context_lengths:
        if context_len > config.max_seq_len:
            print(f"{context_len:>8}  SKIPPED (> max_seq_len {config.max_seq_len})")
            continue

        ids = list(range(1, context_len + 1))

        prefill_times = bench_prefill(model, ids, device, args.bench_runs)
        avg_prefill_ms = sum(prefill_times) / len(prefill_times) * 1000
        prefill_tps = context_len / (avg_prefill_ms / 1000)

        gen_times = bench_generate(model, ids[:min(32, context_len)], args.gen_tokens, device, args.bench_runs)
        avg_gen_time = sum(elapsed for elapsed, _ in gen_times) / len(gen_times)
        avg_gen_tokens = sum(count for _, count in gen_times) / len(gen_times)
        gen_tps = avg_gen_tokens / avg_gen_time if avg_gen_time > 0 else 0

        caches = [{} for _ in model.layers]
        with torch.no_grad():
            model(torch.tensor([ids], device=device), caches=caches, pos=0)
        cache_kb = model.cache_memory_bytes(caches) / 1024

        print(f"{context_len:>8} {avg_prefill_ms:>10.1f}ms {prefill_tps:>12.0f} {gen_tps:>12.1f} {cache_kb:>8.1f}")


def _run_compact_benchmark(model, config, args, device):
    print(f"\n{'='*70}")
    print("AUTO-COMPACT BENCHMARK")
    print(f"{'='*70}")
    max_ctx = max(length for length in args.context_lengths if length <= config.max_seq_len)
    ids = list(range(1, max_ctx + 1))
    before, after, evicted, compact_duration = bench_compact(model, ids, args.gen_tokens, device)
    print(f"  Context: {max_ctx} tokens")
    print(f"  Before compact: {before/1024:.1f} KB")
    print(f"  After compact:  {after/1024:.1f} KB ({(1-after/max(before,1))*100:.0f}% reduction)")
    print(f"  Tokens evicted: {evicted}")
    print(f"  Compact time:   {compact_duration*1000:.2f} ms")


def main():
    args = parse_args()
    device = get_device(args.device)
    print(f"Device: {device}")

    model, config = _load_model(args, device)
    print(f"Model: {args.preset}, {model.num_params():,} params, {model.num_active_params():,} active")
    print(f"Config: d={config.d_model}, layers={config.n_layers}, experts={config.n_experts}, "
          f"hybrid={config.hybrid}, max_seq={config.max_seq_len}, window={config.attn_window}")

    if device.type == "cuda":
        mem_model = torch.cuda.memory_allocated() / 1024 / 1024
        print(f"Model VRAM: {mem_model:.1f} MB")

    _run_context_benchmarks(model, config, args, device)
    _run_compact_benchmark(model, config, args, device)


if __name__ == "__main__":
    main()
