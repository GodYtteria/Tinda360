import argparse
import json
import subprocess
import sys
from pathlib import Path

import build_dataset

HERE = Path(__file__).parent


NO_TOOL = 'no_tool'
FIELD_COUNT = 3


def load_cases(path):
    cases = []
    for line_number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), start=1):
        if not line.strip():
            continue
        fields = line.split('|')
        if len(fields) != FIELD_COUNT:
            raise ValueError(f'{path}:{line_number}: expected query|tool|argument, got {line!r}')
        query, tool, expected = (field.strip() for field in fields)
        arguments = json.loads(expected) if expected.startswith('{') else (
            {'product_name': expected} if expected else {}
        )
        cases.append((query, tool, arguments))
    return cases


def values_match(expected, actual):
    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        try:
            return float(actual) == float(expected)
        except (TypeError, ValueError):
            return False
    return str(actual).strip().lower() == str(expected).strip().lower()


def model_arguments(expected):
    return {
        key: value
        for key, value in expected.items()
        if key not in build_dataset.ENTITY_ARGUMENTS
    }


def arguments_match(expected, actual):
    actual = actual or {}
    return all(
        values_match(value, actual.get(key, ''))
        for key, value in expected.items()
    )


def run_model(checkpoint, queries):
    process = subprocess.run(
        [sys.executable, str(HERE / 'eval.py'), '--checkpoint', checkpoint, '--pipe'],
        input='\n'.join(queries) + '\n', capture_output=True, text=True, cwd=HERE,
    )
    if process.returncode != 0:
        raise RuntimeError(f'eval.py exited with {process.returncode}: {process.stderr.strip()}')
    outputs = [json.loads(line) for line in process.stdout.splitlines() if line.startswith('{')]
    if len(outputs) != len(queries):
        raise RuntimeError(f'eval.py returned {len(outputs)} results for {len(queries)} queries')
    return outputs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--checkpoint', default='checkpoints/best.pt')
    parser.add_argument('--cases', default=str(HERE / 'novel_eval.txt'))
    arguments = parser.parse_args()
    cases = load_cases(Path(arguments.cases))
    outputs = run_model(arguments.checkpoint, [case[0] for case in cases])
    tool_hits = 0
    argument_total = 0
    argument_hits = 0
    for (query, tool, expected), output in zip(cases, outputs):
        predicted = output.get('tool') or NO_TOOL
        tool_ok = predicted == tool
        tool_hits += tool_ok
        arguments_ok = True
        model_expected = model_arguments(expected)
        if model_expected:
            argument_total += 1
            arguments_ok = arguments_match(model_expected, output.get('args'))
            argument_hits += arguments_ok
        status = 'OK ' if tool_ok and arguments_ok else 'BAD'
        print(status, query, '->', predicted, output.get('args') or {})
    print(f'tool accuracy: {tool_hits}/{len(cases)}')
    if argument_total:
        print(f'argument accuracy: {argument_hits}/{argument_total}')


if __name__ == '__main__':
    main()
