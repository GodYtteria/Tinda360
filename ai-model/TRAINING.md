# YtteriaDragon Training Settings

## Current Setup (November 2026)

**Preset:** `5M-tinda360` (5.6M total / 2.3M active)
**Data:** 4,409 tool-calling examples, built by `build_dataset.py` from `queries/`, `model_queries/` and `conversations.jsonl` (20 tools, 8 registers)
**Hardware:** RTX A5000 Laptop 16GB VRAM

## Tool-Only Targets

The model picks the tool and the numeric arguments only. Product and customer names are never in its training targets and never in the tool list it sees.

**Why:** at 5.6M params the model does not copy a new name from the question. It writes a name it memorised from training (`bigas`, `Datu Puti suka`) whatever the question says. Every shop also has its own inventory, so the model cannot know the right names anyway.

**How it works:**
- `build_dataset.py` strips `product_name` and `customer_name` from every assistant tool call (`magkano bigas?` → `get_product_info {}`). Query files still label the product (`|| bigas`) so the tool result and the audit can check it.
- `train.py`, `eval.py` and the app (`YumiEngine.formatToolDefinitions`) all hide those names from the tool list, so the model sees `get_product_info()`. A Dart test keeps the app text identical to the training text.
- The app fills the name in from the question and the shop's own inventory, by id (`groundProductArgument` → `EntityResolver`). No match or more than one match: the app asks or says the product is not in the inventory, never guesses.
- Numeric arguments (timeframe, budget, days, threshold) must still come from the question, never invented.

**Measured on the phone with the real model** (`integration_test/model_tool_call_device_test.dart`): right tool on 6 of 6 product questions, wrong name on 6 of 6, right product in all 6 replies.

## Training Commands

### 5M preset (current — for <5K examples)
```bash
pgrep -a python | grep train  # kill duplicates
nvidia-smi                     # VRAM must be clean
rm -f tokenizer.json checkpoints/*.pt checkpoints/train_log.csv

PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True python train.py \
  --preset 5M-tinda360 --skip-pretrain --epochs 50 \
  --batch-size 54 --effective-batch 216 --device cuda --patience 15 \
  --eval-interval 10
```

`--eval-interval 10` matters: a run is only about 950 steps, so the default of 100 gives too few validation checks for `best.pt` and early stopping.

### 50M preset (future — for 10K+ examples)
```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True python train.py \
  --preset 50M-tinda360 --skip-pretrain --epochs 50 \
  --batch-size 54 --effective-batch 216 --device cuda --patience 15
```

## Batch Size Limits (50M, with optimizer)

| Batch | Peak VRAM | Status |
|-------|-----------|--------|
| 48 | 13.3 GB | Safe |
| 54 | 15.0 GB | Optimal |
| 56 | 15.3 GB | Tight |
| 58+ | OOM | Too big |

5M preset uses ~3-4 GB — batch size not the bottleneck.

## After Training

```bash
# Blind test (the real measure; novel_eval.txt is never trained on)
python eval_novel.py --checkpoint checkpoints/best.pt

# In-distribution eval (held-back split of the training data; reads high)
python eval.py --checkpoint checkpoints/best.pt

# Interactive eval
python eval.py --checkpoint checkpoints/best.pt --interactive

# Pipe queries
echo -e "magkano bigas?\nsino may utang?" | python eval.py --checkpoint checkpoints/best.pt --pipe

# Benchmarks
python benchmark.py --checkpoint checkpoints/best.pt

# Export (q8_0 is half the size of f16 with the same blind-test score)
python export_gguf.py --checkpoint checkpoints/best.pt --output tinda360.gguf --quantize q8_0

# On the phone, with the real engine and model.
# WARNING: flutter test uninstalls the app when it finishes, which deletes the
# shop's data on that phone. Back up first, or use a phone with no real data.
flutter test integration_test -d <device> --dart-define-from-file=dart_defines.json

# Charts
python gen_charts.py --log checkpoints/train_log.csv
```

## Training History

| Run | Preset | Data | Val Loss | Tool Acc | Notes |
|-----|--------|------|----------|----------|-------|
| 1 | 50M | 2,244 | 0.78 | 0% | Overfits, collapsed to canned responses |
| 2 | 5M | 2,244 | 0.82 | 0% | Fixed tokenizer ByteLevel decoder. eval.py format wrong (not ChatML) |
| 3 | 5M | 2,244 | 0.82 | 93.0% | Fixed eval.py (ChatML) + all-20-tools training. skip_special_tokens bug |
| 4 | 5M | 2,309 | 0.89 | 98.6% | +65 targeted examples for 5 weak tools |
| 5 | 5M | 2,317 | 0.91 | 97.4% | Variance in test split |
| 6 | 5M | 2,328 | 0.95 | 97.2% | Variance in test split |
| 7 | 5M | 2,339 | 0.78 | 99.1% | In-distribution split only; the shipped model from this run scored 4/58 on the blind test |

Runs 1 to 7 measured a split of the training data, which shares phrasings with training. From run 8 on, "Tool Acc" is the blind test `novel_eval.txt` (58 questions, none trained on).

| Run | Preset | Data | Best Val Loss | Blind tool | Blind args | Notes |
|-----|--------|------|---------------|------------|------------|-------|
| 8 | 5M | 1,250 | 0.48 | 6/58 | 2/21 | Hand-written queries only; collapsed to two answers |
| 9 | 5M | 3,560 | 0.81 | 18/58 | 3/21 | Added 2,311 recovered conversations |
| 10 | 5M | 3,710 | 0.79 | 24/58 | 2/21 | Product-name questions from every kind of grocery |
| 11 | 5M | 4,409 | 0.65 | 24/58 | 3/21 | +699 English and Tagalog questions for thin tools; shipped as q8_0 (5.4 MB) |
| 12 | 5M | 4,409 | 0.66 | 21/58 | 1/13 | Tool-only targets (run 11 rescored: 24/58, 3/13). Not better; run 11 stays in the app. Within noise for 58 questions |

## Lessons Learned

1. **Model size must match data size.** 50M params on 2K examples = memorization, 0% tool accuracy.
2. **Tokenizer needs ByteLevel decoder.** Without it, decode output shows raw `Ġ` and `Ċ`.
3. **eval.py must use ChatML.** Model trained on `<|im_start|>` format, not bare text.
4. **Loss masking critical.** Without SUKLI-style masking, model memorizes user queries instead of learning responses.
5. **Selective tool defs.** Training shows 4-5 tools per example. Eval with all 20 is distribution shift.
6. **Quality over quantity.** 2,244 diverse examples (96% unique) > 41K template junk (36% unique).
7. **Measure on a blind set.** A split of the training data said 99%; questions the model never saw said 7%.
8. **Keep names out of the model.** A small model memorises names instead of copying them. The app resolves names against each shop's inventory by id.
