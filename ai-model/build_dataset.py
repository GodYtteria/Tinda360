import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import gen_tool_rows as generator

QUERIES_DIRECTORY = Path(__file__).parent / 'queries'
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
    result = generator._result_for(tool_name, arguments)
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
    for path in sorted(QUERIES_DIRECTORY.glob('*.txt')):
        rows.extend(rows_for_file(path))
    held_out = held_out_queries()
    seen = {}
    unique = []
    for row in rows:
        key = row['messages'][0]['content'].strip().lower()
        if key in held_out:
            raise ValueError(f'held-out query is also in training data: {key!r}')
        label = json.dumps(row['messages'][1].get('tool_calls'), sort_keys=True)
        if key in seen and seen[key] != label:
            raise ValueError(f'query has two different labels: {key!r}')
        if key not in seen:
            seen[key] = label
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
