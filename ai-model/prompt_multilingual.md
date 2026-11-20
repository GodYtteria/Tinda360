# Tinda360 Multilingual Data Writing Guide

## Resume Instructions

Continue writing `tinda360_tool_calling.jsonl` — currently 28 hand-crafted examples. Target: 2,000+. All 20 tools covered, all registers below.

Read existing 28 examples first to match style and format. Every example MUST be genuinely unique — no template fills.

## 8 Language Registers (cover ALL equally)

### 1. Formal Filipino (po/opo, complete sentences)
```
"Patingin po ng mga produktong mababang stock"
"Magkano po ang kabuuang benta natin ngayong araw?"
"Pwede po bang makita ang listahan ng may utang?"
"Mayroon po ba tayong mga panindang malapit nang mag-expire?"
```
Reply style: "Narito po ang..." / "Mayroon po tayong..." / respectful

### 2. Casual Tagalog (walang po, bakya, tambay)
```
"uy patingin ng benta"
"sino ba may utang satin"
"meron pa ba tayong itlog"
"bat ang baba ng sales ngayon ah"
```
Reply style: casual, friendly, may humor

### 3. Bisaya-mixed
```
"pila ang bigas boss"
"naa pa bay mantika"
"kinsa may utang"
"unsay best seller karon"
"tag pila ang itlog"
```
Reply style: respond in Taglish pero acknowledge Bisaya terms

### 4. Ilokano-mixed
```
"mano ti bigas"
"adda pay sardinas"
"siasino ti agutang"
"ania ti best seller"
```
Reply style: respond in Taglish pero acknowledge Ilokano

### 5. Pure English
```
"Show me today's sales report"
"Who has outstanding credit?"
"What's our stock level for cooking oil?"
"Are any products expiring soon?"
"How does today compare to yesterday?"
```
Reply style: full English, professional but warm

### 6. Heavy Taglish (code-switching every phrase)
```
"check mo nga yung sales today pati yung low stock"
"sino yung customer na laging nag-uutang tapos hindi nagbabayad"
"compare mo nga yung benta natin ngayon vs kahapon kasi feeling ko bumaba"
"yung top products natin this week, patingin nga"
```
Reply style: match the mix — Taglish with natural switching

### 7. txtspk / Abbreviations / Typos
```
"mgkno bgas"
"sino my utng"
"stck ng itlg"
"bnta ngyn"
"sles rprt"
"my expayr na ba"
"bsta slrs"
```
Reply style: respond normally (don't mirror the txtspk)

### 8. Polite with Emotion (naku, grabe, hay nako)
```
"Naku Yumi ang baba ng benta ngayon!"
"Grabe ang dami ng utang nila!"
"Hay nako parang ubos na lahat ng stock"
"Jusko sino na naman ang nag-utang"
"Ayy maganda pala ang sales ngayon!"
```
Reply style: empathize, match energy, then give data

## Tool-Calling Categories (target counts per register)

Each register should have examples of:
- Single tool call + natural reply: 8-10 per register
- Multi-turn conversations (2-4 turns): 5-6 per register
- Parallel multi-call: 3-4 per register
- Abstention (no tool needed): 2-3 per register
- Edge cases (empty/zero results): 2-3 per register
- Error recovery: 1-2 per register

## JSONL Format (SUKLI-compatible)

First line has full tool definitions (already written). All other lines use `"tools": "@tinda360_tools"`.

```json
{"source":"tinda360/<type>","tools":"@tinda360_tools","messages":[
  {"role":"user","content":"<natural query>"},
  {"role":"assistant","content":"","tool_calls":[{"name":"<tool>","arguments":{...}}]},
  {"role":"tool","name":"<tool>","content":"{<realistic JSON result>}"},
  {"role":"assistant","content":"<natural response using ONLY data from tool result>","tool_calls":[]}
]}
```

Source types: `single`, `multi-turn`, `multi-call`, `no-tool`, `abstention`, `edge-case`, `language-en`, `language-fil`, `language-bis`, `language-ilo`, `language-txtspk`, `language-emotional`

## Critical Rules

1. **Never invent data** — assistant ONLY uses numbers from tool_result
2. **Responses match user's language** — if user speaks English, reply in English
3. **Every example genuinely unique** — different sentence structure, not word swaps
4. **Tool results vary** — different amounts, names, counts per example
5. **Natural conversation flow** — not robotic, sounds like a real store owner talking
6. **Realistic sari-sari store data** — prices make sense (bigas ₱250/sack, candy ₱1/pc)
7. **Filipino names for customers** — Aling/Mang/Ate/Kuya/Nanay/Tito + Filipino first names
8. **Products are generic** — bigas, itlog, mantika, NOT brand names

## Existing Data Reference

The app (chat_notifier.dart) already handles these 23 intents:
greeting, thanks, help, sales, top_products, low_stock, utang, utang_risk,
sales_compare, slow_moving, store_info, product_count, expenses, expiryAlert,
profit_margin, sales_trend, busiest_hours, suki_loyalty, payment_breakdown,
stock_forecast, product_lookup, restock_budget, overview

## After Data Writing

1. Run diversity audit
2. Update train.py for SUKLI-style loss masking
3. Delete tokenizer.json (retrain)
4. Train 5M-tinda360 preset
5. Evaluate with `python eval.py --checkpoint checkpoints/best.pt --interactive`
