# -*- coding: utf-8 -*-
"""
visualization.py
作用：从 MySQL 读取 ADS 层结果，用 pyecharts 生成 4 张可交互图表（HTML）
生成的图表在 output/ 目录，双击用浏览器打开

运行前：sql/01~06 全部执行完毕
依赖：pip install pymysql pyecharts
运行：
    cd C:\\Users\\wut98\\Desktop\\ecommerce-dw
    python scripts/visualization.py
"""

from pathlib import Path

import pymysql
from pyecharts import options as opts
from pyecharts.charts import Bar, Funnel, Line, Pie

# ===================== 数据库配置（和 load_data.py 保持一致） =====================
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': '988664',   # ←←← 改成你的 MySQL 密码
    'database': 'ecommerce_dw',
    'charset':  'utf8mb4',
}
# ===================================================================================

OUT_DIR = Path(__file__).resolve().parent.parent / 'output'
OUT_DIR.mkdir(exist_ok=True)

conn = pymysql.connect(**DB_CONFIG)
cursor = conn.cursor(pymysql.cursors.DictCursor)


def query(sql):
    cursor.execute(sql)
    return cursor.fetchall()


# ---------- 图1：整体转化漏斗 ----------
rows = query("SELECT uv_pv, uv_fav_cart, uv_buy FROM ads_funnel_overall")[0]
funnel = (
    Funnel(init_opts=opts.InitOpts(width='900px', height='500px'))
    .add('用户数', [
        ('浏览',   rows['uv_pv']),
        ('收藏/加购', rows['uv_fav_cart']),
        ('购买',   rows['uv_buy']),
    ])
    .set_global_opts(title_opts=opts.TitleOpts(title='用户转化漏斗（UV口径）'))
)
funnel.render(str(OUT_DIR / '01_funnel.html'))

# ---------- 图2：RFM 分群占比 ----------
rows = query("""
    SELECT segment, COUNT(*) AS cnt FROM ads_rfm_segment
    GROUP BY segment ORDER BY cnt DESC
""")
pie = (
    Pie(init_opts=opts.InitOpts(width='900px', height='500px'))
    .add('用户数', [(r['segment'], r['cnt']) for r in rows])
    .set_global_opts(title_opts=opts.TitleOpts(title='RFM 用户价值分群'))
    .set_series_opts(label_opts=opts.LabelOpts(formatter='{b}: {d}%'))
)
pie.render(str(OUT_DIR / '02_rfm.html'))

# ---------- 图3：24小时活跃曲线 ----------
rows = query("SELECT hr, uv FROM ads_hourly_active ORDER BY hr")
line = (
    Line(init_opts=opts.InitOpts(width='900px', height='500px'))
    .add_xaxis([f"{r['hr']}时" for r in rows])
    .add_yaxis('浏览UV', [r['uv'] for r in rows], is_smooth=True)
    .set_global_opts(
        title_opts=opts.TitleOpts(title='24小时用户活跃分布'),
        xaxis_opts=opts.AxisOpts(name='小时'),
        yaxis_opts=opts.AxisOpts(name='UV'),
    )
)
line.render(str(OUT_DIR / '03_hourly.html'))

# ---------- 图4：每日转化率趋势 ----------
rows = query("SELECT * FROM ads_funnel_daily ORDER BY dt")
bar = (
    Bar(init_opts=opts.InitOpts(width='900px', height='500px'))
    .add_xaxis([str(r['dt']) for r in rows])
    .add_yaxis('浏览UV', [r['uv_pv'] for r in rows])
    .add_yaxis('收藏加购UV', [r['uv_fav_cart'] for r in rows])
    .add_yaxis('购买UV', [r['uv_buy'] for r in rows])
    .set_global_opts(title_opts=opts.TitleOpts(title='每日漏斗各阶段UV'))
)
bar.render(str(OUT_DIR / '04_daily_funnel.html'))

cursor.close()
conn.close()

print('4 张图表已生成到 output 目录：')
for p in sorted(OUT_DIR.glob('*.html')):
    print('  -', p.name)
print('\n双击任一文件即可在浏览器查看交互图表。')
