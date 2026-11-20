"""Training script for YtteriaDragon 50M-tinda360 intent classifier.

Three phases:
  1. Tokenizer training (BPE, vocab 8192) — automatic if tokenizer.json missing
  2. Pretraining on raw text (optional, skip with --skip-pretrain)
  3. Intent classification fine-tuning on JSONL data

Usage:
  pip install torch tokenizers
  python train.py --preset 50M-tinda360 --epochs 50
  python train.py --preset 50M-tinda360 --resume checkpoints/best.pt
"""
import argparse
import json
import math
import os
import signal
import time
from pathlib import Path

import torch
from torch.utils.data import Dataset, DataLoader

from model import PRESETS, ModelConfig, YtteriaDragon, muon_groups, MuonOptimizer


def parse_args():
    parser = argparse.ArgumentParser(description="Train YtteriaDragon")
    parser.add_argument("--preset", default="50M-tinda360", choices=list(PRESETS.keys()))
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch-size", type=int, default=16, help="Micro batch size")
    parser.add_argument("--effective-batch", type=int, default=64, help="Effective batch after grad accum")
    parser.add_argument("--lr", type=float, default=0.01, help="Muon learning rate (IMU-1: 0.01, Arcee: 0.001)")
    parser.add_argument("--adamw-lr-scale", type=float, default=0.1)
    parser.add_argument("--weight-decay", type=float, default=0.1)
    parser.add_argument("--warmup-steps", type=int, default=1000, help="Linear warmup steps (research: 1000-2500)")
    parser.add_argument("--min-lr-ratio", type=float, default=0.1, help="Min LR as fraction of peak (2026 consensus: 0.1)")
    parser.add_argument("--max-seq-len", type=int, default=0, help="Override max_seq_len (0=use preset)")
    parser.add_argument("--skip-pretrain", action="store_true")
    parser.add_argument("--checkpoint-dir", default="checkpoints")
    parser.add_argument("--eval-interval", type=int, default=100)
    parser.add_argument("--save-interval", type=int, default=500)
    parser.add_argument("--device", default="auto", choices=["auto", "cuda", "cpu", "xpu"])
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--resume", type=str, default=None, help="Checkpoint path to resume from")
    parser.add_argument("--compile", action="store_true", help="Use torch.compile")
    parser.add_argument("--wandb", action="store_true", help="Log to wandb")
    parser.add_argument("--tokenizer", default="tokenizer.json")
    parser.add_argument("--pretrain-corpus", default="pretrain_corpus.txt")
    parser.add_argument("--patience", type=int, default=0, help="Early stopping patience (0=disabled)")
    return parser.parse_args()



def get_device(choice):
    if choice != "auto":
        return torch.device(choice)
    if torch.cuda.is_available():
        return torch.device("cuda")
    if hasattr(torch, "xpu") and torch.xpu.is_available():
        return torch.device("xpu")
    return torch.device("cpu")



def _collect_tokenizer_texts():
    texts = []
    for fname in ["tinda360_intent_classifier.jsonl", "tinda360_training_data.jsonl"]:
        if not os.path.exists(fname):
            continue
        with open(fname) as file_handle:
            for line in file_handle:
                record = json.loads(line)
                inst = record.get("instruction", "")
                inp_text = record.get("input", "")
                out_text = record.get("output", "")
                texts.append(inst)
                if inp_text:
                    texts.append(inp_text)
                texts.append(out_text)
    if os.path.exists("tinda360_tool_calling.jsonl"):
        with open("tinda360_tool_calling.jsonl") as file_handle:
            for line in file_handle:
                record = json.loads(line)
                for message in record.get("messages", []):
                    if message["role"] in ("user", "assistant"):
                        texts.append(message.get("content", ""))
                        for tool_call in message.get("tool_calls", []):
                            texts.append(json.dumps(tool_call))
                    elif message["role"] == "tool":
                        texts.append(message.get("content", ""))
    if os.path.exists("pretrain_corpus.txt"):
        with open("pretrain_corpus.txt") as file_handle:
            for line in file_handle:
                texts.append(line.strip())
    return texts


def _build_bpe_tokenizer(corpus_path, vocab_size):
    from tokenizers import Tokenizer, models, trainers, pre_tokenizers, processors, decoders
    tokenizer = Tokenizer(models.BPE(unk_token="[UNK]"))
    tokenizer.pre_tokenizer = pre_tokenizers.ByteLevel(add_prefix_space=False)
    trainer = trainers.BpeTrainer(
        vocab_size=vocab_size,
        special_tokens=["[PAD]", "[BOS]", "[EOS]", "[UNK]",
                        "<|im_start|>", "<|im_end|>",
                        "<tool_call>", "</tool_call>", "<tool_result>", "</tool_result>"],
        min_frequency=2,
        show_progress=True,
    )
    tokenizer.train([corpus_path], trainer)
    tokenizer.decoder = decoders.ByteLevel()
    tokenizer.post_processor = processors.TemplateProcessing(
        single="[BOS] $A [EOS]",
        special_tokens=[("[BOS]", tokenizer.token_to_id("[BOS]")),
                        ("[EOS]", tokenizer.token_to_id("[EOS]"))],
    )
    return tokenizer


def train_tokenizer(path, vocab_size=8192):
    print("Phase 1: Training BPE tokenizer...")
    texts = _collect_tokenizer_texts()
    corpus_path = "__tokenizer_corpus.txt"
    with open(corpus_path, "w") as file_handle:
        for text in texts:
            file_handle.write(text + "\n")
    tokenizer = _build_bpe_tokenizer(corpus_path, vocab_size)
    tokenizer.save(path)
    os.remove(corpus_path)
    print(f"  Tokenizer saved: {path} (vocab={tokenizer.get_vocab_size()})")
    return tokenizer


def load_tokenizer(path, vocab_size=8192):
    from tokenizers import Tokenizer
    if not os.path.exists(path):
        return train_tokenizer(path, vocab_size)
    tok = Tokenizer.from_file(path)
    print(f"  Tokenizer loaded: {path} (vocab={tok.get_vocab_size()})")
    return tok



class TextDataset(Dataset):
    """Causal LM dataset with SUKLI-style loss masking.

    Each item is a list of (text, trainable) segments. Only assistant turns are
    trainable — user queries, system prompts, and tool results get -100 targets.
    This prevents the model from wasting capacity memorizing input patterns
    and forces it to learn response generation only.
    """
    def __init__(self, segment_lists, tokenizer, max_len):
        self.tokenizer = tokenizer
        self.max_len = max_len
        self.pad_id = tokenizer.token_to_id("[PAD]")
        self.data = []
        for segments in segment_lists:
            ids = []
            mask = []
            for text, trainable in segments:

                enc = tokenizer.encode(text, add_special_tokens=False)
                toks = enc.ids
                ids.extend(toks)
                mask.extend([trainable] * len(toks))

            bos = tokenizer.token_to_id("[BOS]")
            eos = tokenizer.token_to_id("[EOS]")
            if bos is not None:
                ids = [bos] + ids
                mask = [False] + mask
            if eos is not None:
                ids = ids + [eos]
                mask = mask + [False]

            ids = ids[:max_len]
            mask = mask[:max_len]
            if len(ids) >= 4:
                self.data.append((ids, mask))

    def __len__(self):
        return len(self.data)

    def __getitem__(self, data_index):
        ids, mask = self.data[data_index]
        seq_len = len(ids)

        padded_ids = ids + [self.pad_id] * (self.max_len - seq_len)
        padded_mask = mask + [False] * (self.max_len - seq_len)
        input_tokens = torch.tensor(padded_ids[:-1], dtype=torch.long)
        target_tokens = torch.tensor(padded_ids[1:], dtype=torch.long)

        train_mask = padded_mask[1:]
        for position in range(len(train_mask)):
            if not train_mask[position]:
                target_tokens[position] = -100
        return input_tokens, target_tokens


def format_tool_calls(tool_calls):
    """Format tool calls with special tokens."""
    parts = []
    for tc in tool_calls:
        call_json = json.dumps({"name": tc["name"], "arguments": tc["arguments"]})
        parts.append(f"<tool_call>{call_json}</tool_call>")
    return "\n".join(parts)


def format_tool_result(tool_result_msg):
    """Format a tool result message."""
    return f"<tool_result>{tool_result_msg['content']}</tool_result>"


YUMI_SYSTEM_PROMPT = (
    "<|im_start|>system\n"
    "Ikaw si Yumi, AI assistant ng sari-sari store. "
    "Sumagot sa Taglish. Gumamit ng tools para kunin ang data mula sa database. "
    "Huwag mag-imbento ng datos — always call a tool first. "
    "Maging friendly, concise, at helpful.<|im_end|>"
)


def format_tool_definitions(tools, called_names=None, max_decoys=3):
    """Format tool definitions as compact listing. Only include called tools + a few decoys
    to fit within max_seq_len (full 20-tool listing is ~300 tokens, too long for 512 seq)."""
    import random as _rng
    if isinstance(tools, str):
        return ""
    all_defs = {}
    for tool_entry in tools:
        function_def = tool_entry["function"]
        params = function_def.get("parameters", {}).get("properties", {})
        param_str = ", ".join(f"{prop_key}: {prop_val.get('type', '?')}" for prop_key, prop_val in params.items())
        all_defs[function_def["name"]] = f"{function_def['name']}({param_str})"
    if called_names:

        selected = [all_defs[tool_name] for tool_name in called_names if tool_name in all_defs]
        decoy_pool = [defn for tool_name, defn in all_defs.items() if tool_name not in called_names]
        selected += _rng.sample(decoy_pool, min(max_decoys, len(decoy_pool)))
        _rng.shuffle(selected)
        return "\n".join(selected)
    return "\n".join(all_defs.values())


def _load_all_tools_from_jsonl(fname):
    with open(fname) as file_handle:
        first_line = json.loads(file_handle.readline())
        tools = first_line.get("tools")
        return tools if isinstance(tools, list) else None


def _build_message_segments(messages, all_tools):
    segments = []
    segments.append((YUMI_SYSTEM_PROMPT + "\n", False))
    if all_tools:
        all_defs = format_tool_definitions(all_tools, called_names=None)
        segments.append((f"<|im_start|>system\nTools:\n{all_defs}<|im_end|>\n", False))
    for msg in messages:
        role = msg["role"]
        if role == "user":
            segments.append((f"<|im_start|>user\n{msg['content']}<|im_end|>\n", False))
        elif role == "assistant":
            tool_calls = msg.get("tool_calls", [])
            content = msg.get("content", "")
            segments.append(("<|im_start|>assistant\n", False))
            body = content or ""
            for tool_call in tool_calls:
                call_json = json.dumps({"name": tool_call["name"], "arguments": tool_call["arguments"]})
                body += ("\n" if body else "") + f"<tool_call>\n{call_json}\n</tool_call>"
            is_trainable = msg.get("train", True)
            segments.append((f"{body}<|im_end|>\n", is_trainable))
        elif role == "tool":
            segments.append((f"<|im_start|>user\n<tool_response>\n{msg['content']}\n</tool_response><|im_end|>\n", False))
    return segments


def load_tool_calling_data():
    fname = "tinda360_tool_calling.jsonl"
    if not os.path.exists(fname):
        raise FileNotFoundError(f"training data not found: {os.path.abspath(fname)}")
    all_tools = _load_all_tools_from_jsonl(fname)
    all_segments = []
    with open(fname) as file_handle:
        for line in file_handle:
            record = json.loads(line)
            messages = record.get("messages", [])
            segments = _build_message_segments(messages, all_tools)
            if len(segments) > 2:
                all_segments.append(segments)
    return all_segments


def load_pretrain_data(path):
    """Load raw text for pretraining."""
    texts = []
    if not os.path.exists(path):
        return texts
    with open(path) as pretrain_file:
        chunk = []
        for line in pretrain_file:
            line = line.strip()
            if not line:
                if chunk:
                    texts.append(" ".join(chunk))
                    chunk = []
            else:
                chunk.append(line)
        if chunk:
            texts.append(" ".join(chunk))
    return texts



def cosine_lr(step, total_steps, warmup_steps, max_lr, min_lr_ratio=0.1):
    """Cosine decay with linear warmup. Floor at 1/10 peak LR (2026 consensus: DeepSeek V4, Arcee Trinity)."""
    min_lr = max_lr * min_lr_ratio
    if step < warmup_steps:
        return min_lr + (max_lr - min_lr) * (step + 1) / warmup_steps
    progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
    return min_lr + 0.5 * (max_lr - min_lr) * (1 + math.cos(math.pi * progress))



class Trainer:
    def __init__(self, model, optimizer, device, args):
        self.model = model
        self.optimizer = optimizer
        self.device = device
        self.args = args
        self.best_val_loss = float("inf")
        self.global_step = 0
        self.tokens_seen = 0
        self.interrupted = False
        self.pad_id = None
        self.wandb_run = None

        Path(args.checkpoint_dir).mkdir(parents=True, exist_ok=True)
        signal.signal(signal.SIGINT, self._handle_interrupt)


        self.log_path = os.path.join(args.checkpoint_dir, "train_log.csv")
        if not os.path.exists(self.log_path):
            with open(self.log_path, "w") as log_file:
                log_file.write("step,train_loss,val_loss,lr,tokens_per_sec,phase\n")

        if args.wandb:
            try:
                import wandb
                self.wandb_run = wandb.init(project="tinda360", config=vars(args))
            except ImportError:
                print("  wandb not installed, skipping")

    def _handle_interrupt(self, sig, frame):
        print("\n  Interrupted! Saving checkpoint...")
        self.save_checkpoint("interrupted.pt")
        self.interrupted = True

    def save_checkpoint(self, name):
        path = os.path.join(self.args.checkpoint_dir, name)

        raw = getattr(self.model, "_orig_mod", self.model)
        state = {
            "model": raw.state_dict(),
            "step": self.global_step,
            "tokens": self.tokens_seen,
            "best_val_loss": self.best_val_loss,
            "config": raw.config.__dict__,
            "optimizer": self.optimizer.state_dict(),
        }
        torch.save(state, path)
        print(f"  Checkpoint saved: {path}")

    def load_checkpoint(self, path):
        print(f"  Loading checkpoint: {path}")
        state = torch.load(path, map_location=self.device, weights_only=False)
        raw = getattr(self.model, "_orig_mod", self.model)

        saved_vocab = state["config"].get("vocab_size", 0)
        current_vocab = raw.config.vocab_size
        if saved_vocab != current_vocab and saved_vocab > 0:
            print(f"  WARNING: checkpoint vocab={saved_vocab}, current={current_vocab}")
            print(f"  Loading weights with strict=False (embedding/lm_head will reinit)")
            raw.load_state_dict(state["model"], strict=False)
        else:
            raw.load_state_dict(state["model"])
        if "optimizer" in state and saved_vocab == current_vocab:
            self.optimizer.load_state_dict(state["optimizer"])
        else:
            print("  Optimizer state skipped (vocab mismatch or missing)")
        self.global_step = state.get("step", 0)
        self.tokens_seen = state.get("tokens", 0)
        self.best_val_loss = state.get("best_val_loss", float("inf"))
        print(f"  Resumed from step {self.global_step}, best_val={self.best_val_loss:.4f}")

    @torch.no_grad()
    def evaluate(self, val_loader):
        self.model.eval()
        total_loss, total_tokens = 0.0, 0
        amp_dtype = torch.bfloat16 if self.device.type == "cuda" and torch.cuda.is_bf16_supported() else None
        for input_batch, target_batch in val_loader:
            input_batch = input_batch.to(self.device)
            target_batch = target_batch.to(self.device)
            n_valid = (target_batch != -100).sum().item()
            with torch.autocast(device_type=self.device.type, dtype=amp_dtype, enabled=amp_dtype is not None):
                _, loss = self.model(input_batch, targets=target_batch)
            total_loss += loss.item() * n_valid
            total_tokens += n_valid
        self.model.train()
        return total_loss / max(total_tokens, 1)

    def _apply_lr(self, lr):
        if isinstance(self.optimizer, MuonOptimizer):
            self.optimizer.lr = lr
            for param_group in self.optimizer.adamw.param_groups:
                param_group["lr"] = lr * self.args.adamw_lr_scale
        else:
            for param_group in self.optimizer.param_groups:
                param_group["lr"] = lr

    def _optimizer_step(self):
        if isinstance(self.optimizer, MuonOptimizer):
            all_params = self.optimizer.params + [
                param for group in self.optimizer.adamw.param_groups for param in group["params"]
            ]
            torch.nn.utils.clip_grad_norm_(all_params, 1.0)
            self.optimizer.step()
        else:
            torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
            self.optimizer.step()
            self.optimizer.zero_grad(set_to_none=True)

    def _log_train_step(self, step_in_phase, lr, accum_loss, accum_tokens, phase_name, t0):
        if step_in_phase % 10 != 0 or accum_tokens == 0:
            return
        avg_loss = accum_loss / accum_tokens
        elapsed = time.time() - t0
        tps = self.tokens_seen / max(elapsed, 1)
        print(f"  step {self.global_step:5d} | loss {avg_loss:.4f} | lr {lr:.6f} | {tps:.0f} tok/s")
        with open(self.log_path, "a") as file_handle:
            file_handle.write(f"{self.global_step},{avg_loss:.6f},,{lr:.8f},{tps:.0f},{phase_name}\n")
        if self.wandb_run:
            import wandb
            wandb.log({"train_loss": avg_loss, "lr": lr, "tokens_per_sec": tps, "step": self.global_step})

    def _run_eval_step(self, val_loader, lr, phase_name):
        val_loss = self.evaluate(val_loader)
        print(f"  >>> val_loss: {val_loss:.4f} (best: {self.best_val_loss:.4f})")
        with open(self.log_path, "a") as file_handle:
            file_handle.write(f"{self.global_step},,{val_loss:.6f},{lr:.8f},,{phase_name}\n")
        if self.wandb_run:
            import wandb
            wandb.log({"val_loss": val_loss, "step": self.global_step})
        return val_loss

    def _process_step(self, step_in_phase, lr, accum_loss, accum_tokens, val_loader, phase_name, t0):
        self._optimizer_step()
        self.global_step += 1
        self.tokens_seen += accum_tokens
        self._log_train_step(step_in_phase, lr, accum_loss, accum_tokens, phase_name, t0)
        if step_in_phase % self.args.eval_interval == 0 and val_loader is not None:
            return self._run_eval_step(val_loader, lr, phase_name)
        return None

    def _handle_val_result(self, val_loss, no_improve_count):
        if val_loss < self.best_val_loss:
            self.best_val_loss = val_loss
            self.save_checkpoint("best.pt")
            return 0
        no_improve_count += 1
        if self.args.patience > 0 and no_improve_count >= self.args.patience:
            print(f"  Early stopping: {no_improve_count} evals without improvement")
            self.save_checkpoint("early_stop.pt")
            return -1
        return no_improve_count

    def _finalize_phase(self, val_loader):
        if val_loader is not None:
            val_loss = self.evaluate(val_loader)
            print(f"  Final val_loss: {val_loss:.4f}")
            if val_loss < self.best_val_loss:
                self.best_val_loss = val_loss
                self.save_checkpoint("best.pt")
        self.save_checkpoint("last.pt")

    def train_phase(self, train_loader, val_loader, total_steps, phase_name, max_lr):
        args = self.args
        grad_accum = max(1, args.effective_batch // args.batch_size)
        warmup_steps = min(args.warmup_steps, total_steps // 4)
        t0 = time.time()
        accum_loss = accum_tokens = step_in_phase = no_improve_count = 0
        amp_dtype = torch.bfloat16 if self.device.type == "cuda" and torch.cuda.is_bf16_supported() else None

        print(f"\n  === {phase_name} ===")
        print(f"  Steps: {total_steps}, Warmup: {warmup_steps}, Grad accum: {grad_accum}")
        self.model.train()

        for _ in range(args.epochs):
            if self.interrupted:
                break
            for batch_idx, (inputs, targets) in enumerate(train_loader):
                if self.interrupted:
                    break
                inputs, targets = inputs.to(self.device), targets.to(self.device)
                lr = cosine_lr(step_in_phase, total_steps, warmup_steps, max_lr, args.min_lr_ratio)
                self._apply_lr(lr)
                with torch.autocast(device_type=self.device.type, dtype=amp_dtype, enabled=amp_dtype is not None):
                    _, loss = self.model(inputs, targets=targets)
                    loss = loss / grad_accum
                loss.backward()
                trainable_tokens = (targets != -100).sum().item()
                accum_loss += loss.item() * grad_accum * trainable_tokens
                accum_tokens += trainable_tokens
                is_last_batch = (batch_idx + 1) == len(train_loader)
                if (batch_idx + 1) % grad_accum == 0 or is_last_batch:
                    step_in_phase += 1
                    val_loss = self._process_step(step_in_phase, lr, accum_loss, accum_tokens, val_loader, phase_name, t0)
                    if val_loss is not None:
                        no_improve_count = self._handle_val_result(val_loss, no_improve_count)
                        if no_improve_count == -1:
                            return
                    if step_in_phase % args.save_interval == 0:
                        self.save_checkpoint(f"step_{self.global_step}.pt")
                    accum_loss = accum_tokens = 0
                    if step_in_phase >= total_steps:
                        break
            if step_in_phase >= total_steps:
                break

        self._finalize_phase(val_loader)



def _build_model_and_trainer(args, config, tokenizer, device):
    model = YtteriaDragon(config).to(device)
    total_params = model.num_params()
    active_params = model.num_active_params()
    print(f"Parameters: {total_params:,} total ({total_params/1e6:.1f}M), {active_params:,} active ({active_params/1e6:.1f}M)")

    muon_params, adamw_groups = muon_groups(model, args.weight_decay, args.adamw_lr_scale)
    adamw = torch.optim.AdamW(adamw_groups, lr=args.lr * args.adamw_lr_scale, betas=(0.9, 0.95))
    optimizer = MuonOptimizer(muon_params, adamw, lr=args.lr)

    if args.compile and hasattr(torch, "compile"):
        print("  torch.compile enabled")
        model = torch.compile(model)

    trainer = Trainer(model, optimizer, device, args)
    trainer.pad_id = tokenizer.token_to_id("[PAD]")
    return trainer


def _run_pretrain_phase(trainer, tokenizer, config, args, device):
    if args.skip_pretrain:
        print("\nPhase 2: Skipped (--skip-pretrain)")
        return
    if not os.path.exists(args.pretrain_corpus):
        print(f"\nPhase 2: Skipped (no {args.pretrain_corpus} found)")
        return
    print(f"\nPhase 2: Pretraining on {args.pretrain_corpus}")
    pretrain_texts = load_pretrain_data(args.pretrain_corpus)
    print(f"  Pretrain texts: {len(pretrain_texts)}")
    if not pretrain_texts:
        return
    pt_segments = [[(text, True)] for text in pretrain_texts]
    pt_dataset = TextDataset(pt_segments, tokenizer, config.max_seq_len)
    n_val = max(1, len(pt_dataset) // 10)
    pt_train, pt_val = torch.utils.data.random_split(pt_dataset, [len(pt_dataset) - n_val, n_val])
    pt_train_dl = DataLoader(pt_train, batch_size=args.batch_size, shuffle=True, num_workers=0, pin_memory=(device.type == "cuda"))
    pt_val_dl   = DataLoader(pt_val,   batch_size=args.batch_size, shuffle=False, num_workers=0, pin_memory=(device.type == "cuda"))
    pt_steps = len(pt_train_dl) * args.epochs // max(1, args.effective_batch // args.batch_size)
    trainer.train_phase(pt_train_dl, pt_val_dl, pt_steps, "Pretraining", args.lr)


def _run_finetune_phase(trainer, tokenizer, config, args, device):
    print("\nPhase 3: Fine-tuning with SUKLI-style loss masking")
    all_segments = load_tool_calling_data()
    print(f"  Tool-calling examples: {len(all_segments)}")
    print(f"  Loss masking: ON (only assistant turns trained)")

    ft_dataset = TextDataset(all_segments, tokenizer, config.max_seq_len)
    print(f"  Tokenized sequences: {len(ft_dataset)}")
    n_val   = max(1, len(ft_dataset) // 10)
    n_train = len(ft_dataset) - n_val
    ft_train, ft_val = torch.utils.data.random_split(
        ft_dataset, [n_train, n_val],
        generator=torch.Generator().manual_seed(args.seed))
    ft_train_dl = DataLoader(ft_train, batch_size=args.batch_size, shuffle=True,  num_workers=0, pin_memory=(device.type == "cuda"))
    ft_val_dl   = DataLoader(ft_val,   batch_size=args.batch_size, shuffle=False, num_workers=0, pin_memory=(device.type == "cuda"))

    grad_accum = max(1, args.effective_batch // args.batch_size)
    steps_per_epoch = math.ceil(len(ft_train_dl) / grad_accum)
    ft_steps = steps_per_epoch * args.epochs
    print(f"  Train: {n_train}, Val: {n_val}")
    print(f"  Steps/epoch: {steps_per_epoch}, Total steps: {ft_steps}")
    trainer.train_phase(ft_train_dl, ft_val_dl, ft_steps, "Fine-tuning", args.lr)


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    args = parse_args()
    torch.manual_seed(args.seed)
    device = get_device(args.device)
    print(f"Device: {device}")

    config = ModelConfig(**PRESETS[args.preset].__dict__)
    if args.max_seq_len > 0:
        config.max_seq_len = args.max_seq_len
    print(f"Preset: {args.preset}")
    print(f"Config: {config}")

    tokenizer = load_tokenizer(args.tokenizer, config.vocab_size)
    actual_vocab = tokenizer.get_vocab_size()
    if actual_vocab != config.vocab_size:
        print(f"  WARNING: tokenizer vocab ({actual_vocab}) != config ({config.vocab_size})")
        print(f"  Adjusting config.vocab_size to {actual_vocab}")
        config.vocab_size = actual_vocab

    trainer = _build_model_and_trainer(args, config, tokenizer, device)
    if args.resume:
        trainer.load_checkpoint(args.resume)

    _run_pretrain_phase(trainer, tokenizer, config, args, device)
    _run_finetune_phase(trainer, tokenizer, config, args, device)

    print(f"\nDone. Best val_loss: {trainer.best_val_loss:.4f}")
    print(f"Checkpoints in: {args.checkpoint_dir}/")
    if trainer.wandb_run:
        import wandb
        wandb.finish()


if __name__ == "__main__":
    main()
