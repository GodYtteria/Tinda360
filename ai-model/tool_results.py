import json

PRODUCTS = {
    'bigas': ('sack', 2500, 1900),
    'itlog': ('piece', 800, 600),
    'toyo': ('bottle', 1800, 1200),
    'mantika': ('bottle', 8500, 6000),
    'banana': ('sack', 7500, 5400),
    'sardinas': ('sack', 4000, 3000),
    'ricesmall': ('sack', 2800, 2200),
    'candy': ('piece', 300, 100),
    'choco': ('piece', 350, 220),
    'biscuit': ('piece', 120, 60),
    'gilroy': ('sachet', 250, 120),
    'icedbottle': ('can', 1200, 1000),
    'coconut': ('bottle', 550, 420),
    'oli': ('bottle', 3500, 2800),
    'Condensed Milk (Klimo)': ('sachet', 450, 350),
    'corn kernel': ('sack', 6000, 4200),
    'page 1': ('piece', 0, 0),
}

CUSTOMERS = {
    'Aling Merly': {'balance': 185000, 'last': 68},
    'Nanay Coring': {'balance': 142000, 'last': 41},
    'Kuya Dante': {'balance': 210000, 'last': 35},
    'Mang Tonyo': {'balance': 320000, 'last': 31},
    'Ate Grace': {'balance': 96000, 'last': 66},
    'Tita Nene': {'balance': 73000, 'last': 72},
}

STORE = {
    'name': 'Tindahan ni Aling Nena',
    'address': '45 Sampaguita St, Brgy. Uno, Malabon',
    'currency': 'PHP',
    'onboarding_done': True,
    'phone': '09171234567',
}


def summarize(timeframe, revenue_minor=281000, cost_minor=126000,
              sale_count=41, items_sold_milli=122000):
    out = {
        'timeframe': timeframe,
        'sale_count': sale_count,
        'revenue_minor': revenue_minor,
        'items_sold_milli': items_sold_milli,
    }
    if cost_minor is not None:
        out['cost_minor'] = cost_minor
    if sale_count > 0 and revenue_minor is not None:
        out.setdefault('profit_minor', revenue_minor - (cost_minor or 0))
    return out

def top_products(timeframe, limit=5, names=('bigas', 'itlog')):
    products = []
    mapping = {
        'bigas': (25000, 10000),
        'itlog': (3000, 1500),
        'toyo': (5000, 1200),
    }
    for name in names:
        qty, rev = mapping[name]
        products.append({
            'product_name': name,
            'total_qty_milli': qty,
            'total_revenue_minor': rev,
        })
    return {'timeframe': timeframe, 'limit': limit, 'products': products}

def product_info(name):

    if name not in PRODUCTS:
        return {'found': False, 'query': name, 'error': 'not_found'}
    unit, price_minor, cost_minor = PRODUCTS[name]
    unit_count = PRODUCTS[name][1]
    return {
        'found': True,
        'product': {
            'name': name,
            'unit': unit,
            'price_minor': price_minor,
            'cost_minor': cost_minor,
            'stock_milli': unit_count * 1000,
        },
    }

def low_stock():
    items = [
        {'name': 'mantika', 'unit': 'bottle', 'stock_milli': 2000,
         'low_stock_at_milli': 8000, 'tracks_stock': True},
        {'name': 'toyo', 'unit': 'bottle', 'stock_milli': 1000,
         'low_stock_at_milli': 2500, 'tracks_stock': True},
        {'name': 'golden biscuits', 'unit': 'piece', 'stock_milli': 500,
         'low_stock_at_milli': 1200, 'tracks_stock': True},
    ]
    return {'threshold_units': 5, 'count': len(items), 'items': items}

def stock_forecast(name):
    unit = PRODUCTS[name][0] if name in PRODUCTS else 'piece'
    return {
        'found': True,
        'product_name': name,
        'unit': unit,
        'current_stock_milli': 5000,
        'window_days': 14,
        'sold_qty_milli_window': 5000,
        'avg_daily_sales_units': 0.36,
        'days_remaining': 11.0,
    }

def utang_list():
    customers = []
    for name, data in CUSTOMERS.items():
        customers.append({
            'name': name,
            'balance_minor': data['balance'] * 100,
            'last_payment_amount_minor': data['last'] * 100,
        })
    return {
        'min_balance_minor': 0,
        'count': len(customers),
        'total_balance_minor': sum(customer['balance_minor'] for customer in customers),
        'customers': customers,
    }

def utang_risk():
    high_risk = [
        {
            'name': 'Mang Tonyo',
            'balance_minor': 320000,
            'outstanding_utang_minor': 300000,
            'outstanding_interest_minor': 20000,
            'oldest_debt_age_days': 31,
            'is_overdue': True,
            'last_payment_amount_minor': 10000,
        },
        {
            'name': 'Ate Grace',
            'balance_minor': 96000,
            'outstanding_utang_minor': 90000,
            'outstanding_interest_minor': 6000,
            'oldest_debt_age_days': 66,
            'is_overdue': True,
            'last_payment_amount_minor': 5000,
        },
    ]
    return {
        'days_overdue': 30,
        'count': len(high_risk),
        'total_at_risk_minor': sum(customer['balance_minor'] for customer in high_risk),
        'high_risk': high_risk,
    }

def expenses(timeframe):
    entries = [
        {'title': 'supplies', 'amount_minor': 520000, 'day_serial': 28},
        {'title': 'utilities', 'amount_minor': 380000, 'day_serial': 29},
        {'title': 'rent', 'amount_minor': 150000, 'day_serial': 29},
    ]
    return {
        'timeframe': timeframe,
        'total_minor': 1010000,
        'count': len(entries),
        'expenses': entries,
    }

def expiry_alerts():
    return {
        'as_of_day_serial': 143,
        'days_ahead': 7,
        'expiring_soon': [
            {
                'name': 'instant milk', 'expiry_date': '2026-11-22',
                'days_left': 3, 'stock_milli': 6000, 'unit': 'pack',
            },
        ],
        'already_expired': [],
    }

def slow_moving():
    return {
        'days': 14,
        'count': 2,
        'items': [
            {
                'name': 'mini notebooks', 'stock_milli': 4000,
                'sold_qty_milli_window': 0,
            },
            {
                'name': 'spice packet', 'stock_milli': 1500,
                'sold_qty_milli_window': 500,
            },
        ],
    }

def profit_margins():
    products = []
    for name in ('bigas', 'itlog', 'candy'):
        unit, price_minor, cost_minor = PRODUCTS[name]
        margin_pct = round(100.0 * (price_minor - cost_minor) / price_minor, 2) if price_minor else 0.0
        products.append({
            'name': name,
            'unit': unit,
            'price_minor': price_minor,
            'cost_minor': cost_minor,
            'margin_minor': price_minor - cost_minor,
            'margin_pct': margin_pct,
        })
    products.sort(key=lambda p: p['margin_pct'], reverse=True)
    return {
        'sort': 'highest',
        'limit': 10,
        'count': len(products),
        'products': products,
        'average_margin_pct': round(sum(product['margin_pct'] for product in products) / len(products), 2),
    }

def sales_compare(period='week'):
    current = {'revenue_minor': 162000, 'sale_count': 23}
    previous = {'revenue_minor': 201000, 'sale_count': 19}
    return {
        'period': 'week',
        'current': current,
        'previous': previous,
        'delta': {
            'revenue_minor': current['revenue_minor'] - previous['revenue_minor'],
            'sale_count': current['sale_count'] - previous['sale_count'],
        },
    }

def sales_trend():
    return {
        'days': 7,
        'series': [
            {'date': '2026-11-11', 'revenue_minor': 310000, 'sale_count': 18},
            {'date': '2026-11-12', 'revenue_minor': 250000, 'sale_count': 12},
            {'date': '2026-11-13', 'revenue_minor': 380000, 'sale_count': 21},
            {'date': '2026-11-14', 'revenue_minor': 240000, 'sale_count': 9},
            {'date': '2026-11-15', 'revenue_minor': 420000, 'sale_count': 25},
        ],
    }

def busiest_hours(timeframe='week'):
    return {
        'timeframe': timeframe,
        'hours': [
            {'hour': 8, 'transaction_count': 42, 'revenue_minor': 64000},
            {'hour': 12, 'transaction_count': 51, 'revenue_minor': 80000},
            {'hour': 15, 'transaction_count': 38, 'revenue_minor': 50000},
            {'hour': 18, 'transaction_count': 47, 'revenue_minor': 71000},
        ],
    }

def suki_loyalty():
    customers = [
        {'customer_name': 'Aling Merly', 'total_spend_minor': 1850000, 'visits': 95},
        {'customer_name': 'Nanay Coring', 'total_spend_minor': 1420000, 'visits': 82},
        {'customer_name': 'Kuya Dante', 'total_spend_minor': 1180000, 'visits': 71},
        {'customer_name': 'Ate Grace', 'total_spend_minor': 960000, 'visits': 65},
        {'customer_name': 'Tita Nene', 'total_spend_minor': 730000, 'visits': 58},
    ]
    return {
        'sort_by': 'spend',
        'limit': 10,
        'customers': customers,
    }

def payment_breakdown():
    return {
        'timeframe': 'today',
        'methods': [
            {'method': 'cash', 'count': 185, 'amount_minor': 2850000},
            {'method': 'ewallet', 'count': 53, 'amount_minor': 805000},
            {'method': 'utang', 'count': 12, 'amount_minor': 210000},
        ],
        'total_count': 250,
        'total_amount_minor': 3865000,
    }

def store_info():
    return dict(STORE)

def product_count():
    active = 9
    return {
        'active_count': active,
        'tracked_count': active - 2,
        'untracked_count': 2,
        'categories': 3,
    }

def restock_suggestions():
    return {
        'budget_minor': 10000,
        'limit': 10,
        'total_cost_minor': 8200,
        'remaining_budget_minor': 1800,
        'suggestions': [
            {
                'name': 'mantika', 'unit_cost_minor': 8500,
                'total_minor': 8500, 'qty_to_order': 1,
                'reason': 'low_stock', 'current_stock_milli': 2000,
            },
            {
                'name': 'toyo', 'unit_cost_minor': 1800,
                'total_minor': 1800, 'qty_to_order': 6,
                'reason': 'demand', 'current_stock_milli': 1000,
            },
        ],
    }

def overview():
    return {
        'as_of_day_serial': 143,
        'sales_today': {'revenue_minor': 281000, 'cost_minor': 126000, 'profit_minor': 155000, 'sale_count': 41},
        'low_stock_count': 3,
        'utang_total_minor': 2100000,
        'expiring_soon_count': 2,
        'expired_count': 0,
    }


def result_for(tool_name, args):
    args = args or {}
    return RESULT_BUILDERS[tool_name](**args) if tool_name not in ('get_low_stock',) else low_stock()

RESULT_BUILDERS = {
    'get_sales_summary': lambda **a: summarize(a.get('timeframe', 'today')),
    'get_top_products': lambda **a: top_products(a.get('timeframe', 'week'), limit=a.get('limit', 5)),
    'get_product_info': lambda **a: product_info(a.get('product_name', '')),
    'get_low_stock': lambda **a: low_stock(),
    'get_stock_forecast': lambda **a: stock_forecast(a.get('product_name', '')),
    'get_utang_list': lambda **a: utang_list(),
    'get_utang_risk': lambda **a: utang_risk(),
    'get_expenses': lambda **a: expenses(a.get('timeframe', 'week')),
    'get_expiry_alerts': lambda **a: expiry_alerts(),
    'get_slow_moving': lambda **a: slow_moving(),
    'get_profit_margins': lambda **a: profit_margins(),
    'get_sales_compare': lambda **a: sales_compare(a.get('period', 'week')),
    'get_sales_trend': lambda **a: sales_trend(),
    'get_busiest_hours': lambda **a: busiest_hours(a.get('timeframe', 'week')),
    'get_suki_loyalty': lambda **a: suki_loyalty(),
    'get_payment_breakdown': lambda **a: payment_breakdown(),
    'get_store_info': lambda **a: store_info(),
    'get_product_count': lambda **a: product_count(),
    'get_restock_suggestions': lambda **a: restock_suggestions(),
    'get_overview': lambda **a: overview(),
}

