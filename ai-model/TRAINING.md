# YtteriaDragon Training Settings

## Current Setup (November 2026)

**Preset:** `5M-tinda360` (5.6M total / 2.3M active)
**Data:** 2,435 tool-calling examples (96%+ diversity, 20 tools, 8 registers)
**Hardware:** RTX A5000 Laptop 16GB VRAM

## Tool Argument Extraction — Known Limitation

**5.6M params cannot reliably extract entity names from queries.** The model correctly selects the tool (98%+ tool accuracy) but always outputs a memorized `product_name` (e.g., "ice candy") instead of the actual product in the query.

**Production solution (already implemented):**
- Model identifies the correct tool → `get_product_info` ✓
- Flutter app ignores the model's `product_name` arg
- `findMentionedProduct(originalQuery, products)` does database fuzzy matching instead
- This correctly extracts "bigas", "asukal", etc. from the query against the real product list

**To fix at model level:**
- Need 50M-tinda360 preset
- Need 10,000+ examples
- Do NOT add product extraction examples to the 5M model — they hurt overall tool accuracy
  - Experiment: +96 product examples → tokenizer grew 4975→5075 tokens → accuracy dropped 98%→90%
  - Root cause: new token distribution requires model to re-learn everything

**Rule: When adding new training data, keep the tokenizer stable. Mass product examples should come as a batch only when switching to 50M preset.**

## Training Commands

### 5M preset (current — for <5K examples)
```bash
pgrep -a python | grep train  # kill duplicates
nvidia-smi                     # VRAM must be clean
rm -f tokenizer.json checkpoints/*.pt checkpoints/train_log.csv

PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True python train.py \
  --preset 5M-tinda360 --skip-pretrain --epochs 50 \
  --batch-size 54 --effective-batch 216 --device cuda --patience 15
```

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
# Batch eval (tool-call accuracy)
python eval.py --checkpoint checkpoints/best.pt

# Interactive eval
python eval.py --checkpoint checkpoints/best.pt --interactive

# Pipe queries
echo -e "magkano bigas?\nsino may utang?" | python eval.py --checkpoint checkpoints/best.pt --pipe

# Benchmarks
python benchmark.py --checkpoint checkpoints/best.pt

# Export
python export_gguf.py --checkpoint checkpoints/best.pt --output tinda360.gguf

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
| **7** | **5M** | **2,339** | **0.78** | **99.1%** | **Best. 2 errors remain. Ready for Flutter.** |

## Lessons Learned

1. **Model size must match data size.** 50M params on 2K examples = memorization, 0% tool accuracy.
2. **Tokenizer needs ByteLevel decoder.** Without it, decode output shows raw `Ġ` and `Ċ`.
3. **eval.py must use ChatML.** Model trained on `<|im_start|>` format, not bare text.
4. **Loss masking critical.** Without SUKLI-style masking, model memorizes user queries instead of learning responses.
5. **Selective tool defs.** Training shows 4-5 tools per example. Eval with all 20 is distribution shift.
6. **Quality over quantity.** 2,244 diverse examples (96% unique) > 41K template junk (36% unique).
