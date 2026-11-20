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
get_product_info()
... (all 20 tools listed)
<|im_end|>
<|im_start|>user
magkano bigas?
<|im_end|>
<|im_start|>assistant
(model generates from here)
```

## Tool Call Format

The model writes the tool and any numbers from the question. It never writes `product_name` or `customer_name`: those are hidden from its tool list and stripped from its training targets. The app fills them in from the question and the shop's inventory, by id, before the call is validated and run.

```
<tool_call>
{"name": "get_product_info", "arguments": {}}
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

## Names Are Filled In by the App

- A 5.6M model memorises product names instead of copying them from the question, so names are not its job.
- `groundProductArgument` resolves the product from the question against the shop's own inventory (`EntityResolver`, by id). One match: it is used. None or several: the app says it is not in the inventory or asks which one.
- This works for any shop and any inventory without retraining.

## Progress Notes (runs, not dates)

- Dataset `ai-model/tinda360_tool_calling.jsonl`: 4,409 rows, SUKLI-style, tool results from `tool_results.py`, 20 tools, 8 registers. Assistant tool calls carry no names.
- Sources: hand-written `queries/*.txt` (also train the app's intent classifier), `model_queries/*.txt` (English and Tagalog, model only) and `conversations.jsonl` (recovered multi-turn conversations, model only).
- Generator: `build_dataset.py`; it drops held-out look-alikes, conflicting labels and rows whose name is not in the question.
- Blind test: `novel_eval.txt` with `eval_novel.py`; see TRAINING.md for the run history.
