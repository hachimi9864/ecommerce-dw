# -*- coding: utf-8 -*-
"""
load_data.py
作用：把 data/UserBehavior.csv 批量导入 MySQL 的 ecommerce_dw.ods_user_behavior
真实天池数据 / 模拟数据都用这一个脚本（字段格式一致）

运行前：
    1. 先在 DBeaver 执行 sql/01_create_ods.sql 建好库和表
    2. 改下面的【数据库配置】，把 PASSWORD 改成你自己的 MySQL 密码
    3. 装依赖：pip install pymysql
运行：
    cd C:\\Users\\wut98\\Desktop\\ecommerce-dw
    python scripts/load_data.py
"""

import csv
import time
from datetime import datetime
from pathlib import Path

import pymysql

# ===================== 数据库配置（改成你自己的） =====================
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': '988664',   # ←←← 只需要改这一行
    'database': 'ecommerce_dw',
    'charset':  'utf8mb4',
}
# ======================================================================

CSV_PATH = Path(__file__).resolve().parent.parent / 'data' / 'UserBehavior.csv'
BATCH_SIZE = 5_000   # 每批插入 5000 行（批量提交比一行一插快几十倍）

INSERT_SQL = """
    INSERT INTO ods_user_behavior
        (user_id, item_id, category_id, behavior_type, behavior_time)
    VALUES (%s, %s, %s, %s, %s)
"""


def main():
    if not CSV_PATH.exists():
        print(f'找不到数据文件：{CSV_PATH}')
        print('请先运行 python scripts/gen_mock_data.py 生成模拟数据，')
        print('或把天池下载的 UserBehavior.csv 放到 data 目录下。')
        return

    if DB_CONFIG['password'].startswith('改成你的'):
        print('！请先用记事本/VSCode 打开本文件，把 PASSWORD 改成你的 MySQL 密码')
        return

    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # 导入前先清空，保证脚本可以反复执行
    cursor.execute('TRUNCATE TABLE ods_user_behavior')

    batch = []
    total = 0
    t0 = time.time()

    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            # 每行: [user_id, item_id, category_id, behavior_type, 时间戳]
            user_id, item_id, category_id, behavior, ts = row
            behavior_time = datetime.fromtimestamp(int(ts))
            batch.append((int(user_id), int(item_id), int(category_id),
                          behavior, behavior_time))

            if len(batch) >= BATCH_SIZE:
                cursor.executemany(INSERT_SQL, batch)
                conn.commit()
                total += len(batch)
                batch.clear()
                speed = total / (time.time() - t0)
                print(f'\r已导入 {total:>9,} 行  速度 {speed:,.0f} 行/秒', end='')

    if batch:  # 最后不足 5000 的零头
        cursor.executemany(INSERT_SQL, batch)
        conn.commit()
        total += len(batch)

    print(f'\n\n导入完成，共 {total:,} 行，耗时 {time.time()-t0:.1f} 秒')

    cursor.execute('SELECT COUNT(*) FROM ods_user_behavior')
    print('数据库内行数校验：', cursor.fetchone()[0])

    cursor.close()
    conn.close()


if __name__ == '__main__':
    main()
