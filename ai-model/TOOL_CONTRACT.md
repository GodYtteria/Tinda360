# Tinda360 Tool Calling Contract

## Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_sales_summary` | Get total revenue, transaction count and items sold for a date range. | `timeframe`: string (required, enum: ['today', 'week', 'month']) |
| `get_top_products` | Get best-selling products ranked by quantity sold. | `timeframe`: string (required, enum: ['today', 'week', 'month']), `limit`: integer (optional, default: 5) |
| `get_product_info` | Look up a product by name: price, stock, cost, category. | `product_name`: string (required) |
| `get_low_stock` | List products below a stock threshold. | `threshold`: integer (optional, default: 5) |
| `get_stock_forecast` | Predict when a product runs out based on sales velocity. | `product_name`: string (required) |
| `get_utang_list` | List customers with outstanding credit. | `min_balance`: number (optional, default: 0) |
| `get_utang_risk` | Rank high-risk debtors by overdue amount and days since payment. | `days_overdue`: integer (optional, default: 30) |
| `get_expenses` | Get operating expenses for a period. | `timeframe`: string (required, enum: ['today', 'week', 'month']) |
| `get_expiry_alerts` | Products nearing or past expiry. | `days_ahead`: integer (optional, default: 7) |
| `get_slow_moving` | Products with zero or low sales in the past N days. | `days`: integer (optional, default: 14) |
| `get_profit_margins` | Products ranked by profit margin. | `sort`: string (optional, enum: ['highest', 'lowest']), `limit`: integer (optional, default: 10) |
| `get_sales_compare` | Compare sales between current and previous period. | `period`: string (optional, enum: ['day', 'week', 'month']) |
| `get_sales_trend` | Daily sales totals for the past N days. | `days`: integer (optional, default: 7) |
| `get_busiest_hours` | Transaction counts grouped by hour. | `timeframe`: string (optional, enum: ['today', 'week', 'month']) |
| `get_suki_loyalty` | Top customers by spend or visit frequency. | `sort_by`: string (optional, enum: ['spend', 'visits']), `limit`: integer (optional, default: 10) |
| `get_payment_breakdown` | Sales split by payment method. | `timeframe`: string (optional, enum: ['today', 'week', 'month']) |
| `get_store_info` | Store profile: name, address, registration. | (none) |
| `get_product_count` | Count of active products in inventory. | (none) |
| `get_restock_suggestions` | Suggest products to restock within a budget. | `budget`: number (optional), `limit`: integer (optional, default: 10) |
| `get_overview` | Full store dashboard: sales, low stock, utang, expiring. | (none) |

## Prompt Format (ChatML)

```
<|im_start|>system
Ikaw si Yumi, AI assistant ng sari-sari store. ...
<|im_end|>
<|im_start|>system
Tools:
get_sales_summary(timeframe: string)
get_product_info(product_name: string)
... (all 20 tools listed)
<|im_end|>
<|im_start|>user
magkano bigas?
<|im_end|>
<|im_start|>assistant
(model generates from here)
```

## Tool Call Format

```
<tool_call>
{"name": "get_product_info", "arguments": {"product_name": "bigas"}}
</tool_call>
```

## Tool Result Format

```
<tool_response>
{"name": "bigas", "price": 25, "cost": 20, "stock": 15, "unit": "kg"}
</tool_response>
```

## Response Rules

- Call a tool first, never invent data
- Reply using ONLY numbers from tool_result JSON
- Match the user's language register (Filipino, English, Bisaya, etc.)
- For no-tool queries (greetings, off-topic), reply without tool calls

## 8 Language Registers

1. Formal Filipino (po/opo)
2. Casual Tagalog
3. Bisaya-mixed
4. Ilokano-mixed
5. Pure English
6. Heavy Taglish
7. txtspk/abbreviations
8. Emotional (naku, grabe, hay nako)

## Known Limitations

- `product_name` extraction unreliable at 5M params (always outputs memorized name)
- Flutter app handles this via `findMentionedProduct()` database fuzzy matching
- Fix requires 50M-tinda360 preset with 10K+ examples


## Progress Notes (runs, not dates)

- Dataset `ai-model/tinda360_tool_calling.jsonl`: 4440 rows, SUKLI-style, canonical tool results (DB-truth), JSON valid, hand-crafted/generated unique, 8 registers, 20 tools.
- Tool-call distribution (high→low): `get_product_info` (1380), `get_sales_summary`, `get_stock_forecast`, `get_utang_list`, `get_sales_compare`, `get_top_products`, `get_utang_risk`, `get_expenses`, ... (more in 6.b).
- Generator: `ai-model/gen_tool_rows.py` (deterministic, args→result consistency) + `ai-model/topper.py`; backups `tinda360_tool_calling_backup_2361/2435.jsonl`.
- Next: after 50M training+eval, export to `assets/ai/model.gguf`, sync `assets/ai/tokenizer.json`, re-audit dataset JSON + tool JSON validity, then report gate.


## Progress Notes - 50M train/eval (runs)

- Data: 4440 rows, SUKLI-style, canonical tool results, JSON valid, hand-crafted/generated unique, 8 registers, 20 tools.
- Eval on 418-test split (`python eval.py --checkpoint checkpoints/best.pt`): Overall 345/444 = 77.7%; Tool sel 329/428 = 76.9%; No-tool 16/16 = 100.0%; `get_product_info` 123/123 = 100%. Low-tool gaps: slow_moving 29%, store_info 35%, payment_breakdown 25%, product_count 36%, suki 23%, sales_trend 47%, utang_list 65% (imbalance-driven).
- Exported: `assets/ai/model.gguf` (50M, 121 MB) + `assets/ai/tokenizer.json` synced from `ai-model/tokenizer.json`.
- To improve low-tool accuracy: more balanced data (lower `get_product_info` share, top up slow_moving/store_info/payment_breakdown/product_count/suki_loyalty/sales_trend/utang_list/expiry_alerts) or more epochs.
