import difflib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import tool_results

QUERIES_DIRECTORY = Path(__file__).parent / 'queries'
MODEL_ONLY_QUERIES_DIRECTORY = Path(__file__).parent / 'model_queries'
DATASET_PATH = Path(__file__).parent / 'tinda360_tool_calling.jsonl'
PRODUCT_SECTION = 'product'
NO_TOOL_FILE = 'no_tool'
REPLY_SEPARATOR = '||'


def parse_query_file(path):
    default_arguments = {}
    entries = []
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith('@ '):
            marker = line[2:].strip()
            default_arguments = PRODUCT_SECTION if marker == PRODUCT_SECTION else json.loads(marker)
            continue
        entries.append((line, default_arguments))
    return entries


def tool_row(tool_name, arguments, query):
    result = tool_results.result_for(tool_name, arguments)
    return {
        'source': 'tinda360/tools',
        'tools': '@tinda360_tools',
        'messages': [
            {'role': 'user', 'content': query},
            {'role': 'assistant', 'content': '', 'tool_calls': [{'name': tool_name, 'arguments': arguments}]},
            {'role': 'tool', 'name': tool_name, 'content': json.dumps(result, ensure_ascii=False)},
        ],
    }


def no_tool_row(query, reply):
    return {
        'source': 'tinda360/no-tool',
        'tools': '@tinda360_tools',
        'messages': [
            {'role': 'user', 'content': query},
            {'role': 'assistant', 'content': reply, 'tool_calls': []},
        ],
    }


def rows_for_file(path):
    rows = []
    for line, default_arguments in parse_query_file(path):
        query, separator, override = [part.strip() for part in line.partition(REPLY_SEPARATOR)]
        if path.stem == NO_TOOL_FILE:
            if not separator or not override:
                raise ValueError(f'{path.name}: missing "{REPLY_SEPARATOR} reply" in line: {line}')
            rows.append(no_tool_row(query, override))
            continue
        if default_arguments == PRODUCT_SECTION:
            if not override:
                raise ValueError(f'{path.name}: missing "{REPLY_SEPARATOR} product" in line: {line}')
            arguments = {'product_name': override}
        elif override:
            arguments = json.loads(override)
        else:
            arguments = dict(default_arguments)
        rows.append(tool_row(path.stem, arguments, query))
    return rows


NOVEL_CASES_PATH = Path(__file__).parent / 'novel_eval.txt'
CONVERSATIONS_PATH = Path(__file__).parent / 'conversations.jsonl'
ENTITY_ARGUMENTS = ('product_name', 'customer_name')
HELD_OUT_SIMILARITY_LIMIT = 0.8


def entity_missing_from_query(row):
    user_text = ' '.join(
        message['content'].lower() for message in row['messages'] if message['role'] == 'user'
    )
    return any(
        not isinstance(call['arguments'][key], str)
        or not call['arguments'][key].strip()
        or call['arguments'][key].lower() not in user_text
        for message in row['messages']
        for call in message.get('tool_calls') or []
        for key in ENTITY_ARGUMENTS
        if key in call['arguments']
    )


def resembles_held_out(query, held_out):
    return any(
        difflib.SequenceMatcher(None, query, case).ratio() >= HELD_OUT_SIMILARITY_LIMIT
        for case in held_out
    )


def row_key(row):
    return row['messages'][0]['content'].strip().lower()


def user_queries(row):
    return [message['content'].strip().lower() for message in row['messages'] if message['role'] == 'user']


def row_label(row):
    return json.dumps(row['messages'][1].get('tool_calls'), sort_keys=True)


def conversation_rows(held_out, curated_keys):
    candidates = [
        json.loads(line)
        for line in CONVERSATIONS_PATH.read_text(encoding='utf-8').splitlines()
        if line.strip()
    ]
    labels_by_key = {}
    for row in candidates:
        labels_by_key.setdefault(row_key(row), set()).add(row_label(row))
    rows = []
    dropped_entity = dropped_held_out = dropped_curated = dropped_conflict = 0
    for row in candidates:
        key = row_key(row)
        if key in curated_keys:
            dropped_curated += 1
            continue
        if len(labels_by_key[key]) > 1:
            dropped_conflict += 1
            continue
        if entity_missing_from_query(row):
            dropped_entity += 1
            continue
        if any(resembles_held_out(query, held_out) for query in user_queries(row)):
            dropped_held_out += 1
            continue
        rows.append(row)
    print(f'conversations: {len(rows)} kept, {dropped_entity} dropped for a name not in the question, '
          f'{dropped_held_out} dropped for resembling a held-out question, '
          f'{dropped_curated} dropped because queries/ or model_queries/ already has the question, '
          f'{dropped_conflict} dropped for conflicting labels')
    return rows


def held_out_queries():
    if not NOVEL_CASES_PATH.exists():
        return set()
    return {
        line.split('|')[0].strip().lower()
        for line in NOVEL_CASES_PATH.read_text(encoding='utf-8').splitlines()
        if line.strip()
    }


def build():
    header = DATASET_PATH.read_text(encoding='utf-8').splitlines()[0]
    rows = []
    for directory in (QUERIES_DIRECTORY, MODEL_ONLY_QUERIES_DIRECTORY):
        for path in sorted(directory.glob('*.txt')):
            rows.extend(rows_for_file(path))
    held_out = held_out_queries()
    rows.extend(conversation_rows(held_out, {row_key(row) for row in rows}))
    seen = {}
    seen_conversations = set()
    unique = []
    for row in rows:
        key = row_key(row)
        leaked = held_out.intersection(user_queries(row))
        if leaked:
            raise ValueError(f'held-out query is also in training data: {sorted(leaked)[0]!r}')
        label = row_label(row)
        if key in seen and seen[key] != label:
            raise ValueError(f'query has two different labels: {key!r}')
        seen[key] = label
        conversation = json.dumps(row['messages'], sort_keys=True, ensure_ascii=False)
        if conversation not in seen_conversations:
            seen_conversations.add(conversation)
            unique.append(row)
    temporary_path = DATASET_PATH.with_suffix('.jsonl.tmp')
    with temporary_path.open('w', encoding='utf-8') as handle:
        handle.write(header + '\n')
        for row in unique:
            handle.write(json.dumps(row, ensure_ascii=False) + '\n')
    os.replace(temporary_path, DATASET_PATH)
    print(f'rows: {len(unique)} (dropped duplicates: {len(rows) - len(unique)})')


if __name__ == '__main__':
    build()
