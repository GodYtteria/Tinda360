import json
import sys

sys.path.insert(0, 'ai-model')
import gen_tool_rows as g

def topper(n_per_low):
    add, rows, seen = g.make_rows()
    reg = 0
    tools_args = {
        'get_slow_moving': {'days': 14},
        'get_payment_breakdown': {'timeframe': 'week'},
        'get_product_count': {},
        'get_store_info': {},
        'get_sales_trend': {'days': 7},
        'get_busiest_hours': {'timeframe': 'week'},
        'get_suki_loyalty': {'sort_by': 'spend', 'limit': 10},
        'get_expiry_alerts': {'days_ahead': 7},
    }
    for tool, args in tools_args.items():
        for _ in range(n_per_low):
            for _attempt in range(15):
                user = g.user_phrases_by_tool(tool, g.next_register(), args)
                if add(tool, dict(args), user):
                    break
    with open(g.DATA_PATH, 'a', encoding='utf-8') as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + '\n')
    print('appended', len(rows))

if __name__ == '__main__':
    count_per_low = int(sys.argv[1]) if len(sys.argv) > 1 else 25
    topper(count_per_low)
