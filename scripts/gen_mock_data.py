# -*- coding: utf-8 -*-
"""
gen_mock_data.py
作用：生成「淘宝用户行为」模拟数据（保底方案，下载不到天池真实数据时用）

字段格式与天池公开数据集完全一致：
    user_id, item_id, category_id, behavior_type, 时间戳(秒)
behavior_type: pv / fav / cart / buy
时间范围：2017-11-25 ~ 2017-12-03（和天池数据集一致，9天）

运行：
    cd C:\\Users\\wut98\\Desktop\\ecommerce-dw
    python scripts/gen_mock_data.py

生成后文件在：data/UserBehavior.csv
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

# ===================== 可调参数 =====================
N_USERS   = 10_000    # 用户数
N_ITEMS   = 100_000   # 商品数（属于下面这些类目）
N_CATE    = 1_000     # 类目数
N_ROWS    = 500_000   # 生成多少行行为（50万跑得很快；想挑战可以改 1_000_000）
SEED      = 42        # 随机种子，保证你每次生成的数据一样，结果可复现
# ====================================================

random.seed(SEED)

START = datetime(2017, 11, 25)
END   = datetime(2017, 12, 3, 23, 59, 59)
SPAN_SECONDS = int((END - START).total_seconds())

# 每个商品预先归属一个类目（10万商品 -> 1千类目）
item_category = [random.randrange(1, N_CATE + 1) for _ in range(N_ITEMS + 1)]

# 行为权重：浏览占绝大多数，收藏/加购/购买依次减少（贴近真实分布）
BEHAVIORS = (['pv'] * 85 + ['fav'] * 5 + ['cart'] * 6 + ['buy'] * 4)

# 预生成一批"高价值用户"（更活跃、更容易买），让 RFM 分层有明显差异
hot_users = set(random.sample(range(1, N_USERS + 1), int(N_USERS * 0.15)))

out_path = Path(__file__).resolve().parent.parent / 'data' / 'UserBehavior.csv'
out_path.parent.mkdir(parents=True, exist_ok=True)

written = 0
with open(out_path, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    for _ in range(N_ROWS):
        # 高价值用户出现概率是普通用户的6倍（让行为向他们集中）
        if random.random() < 0.55:
            user_id = random.choice(tuple(hot_users))
        else:
            user_id = random.randint(1, N_USERS)

        item_id = random.randint(1, N_ITEMS)
        category_id = item_category[item_id]
        behavior = random.choice(BEHAVIORS)

        # 高价值用户更容易出现购买行为
        if user_id in hot_users and random.random() < 0.10:
            behavior = random.choice(['cart', 'buy', 'buy'])

        ts = START + timedelta(seconds=random.randint(0, SPAN_SECONDS))
        writer.writerow([user_id, item_id, category_id,
                         behavior, int(ts.timestamp())])
        written += 1
        if written % 50_000 == 0:
            print(f'已生成 {written:,} 行 ...')

print(f'\n完成！文件：{out_path}')
print(f'共 {written:,} 行，{N_USERS:,} 用户，{N_ITEMS:,} 商品，{N_CATE:,} 类目')
