import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent


def load_cases(path):
    cases = []
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.strip():
            query, tool, product = line.split('|')
            cases.append((query, tool, product))
    return cases


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
    product_total = 0
    product_hits = 0
    for (query, tool, product), output in zip(cases, outputs):
        tool_ok = output.get('tool') == tool
        tool_hits += tool_ok
        extracted = ''
        if product:
            product_total += 1
            extracted = (output.get('args') or {}).get('product_name', '')
            product_hits += extracted.lower() == product.lower()
        print('OK ' if tool_ok else 'BAD', query, '->', output.get('tool'), extracted)
    print(f'tool accuracy: {tool_hits}/{len(cases)}')
    if product_total:
        print(f'product argument accuracy: {product_hits}/{product_total}')


if __name__ == '__main__':
    main()
