# ecommerce-dw

电商数据仓库项目，从原始行为数据入仓到业务分析的完整链路。

## 技术栈

- **MySQL** — 数据存储（utf8mb4，InnoDB）
- **SQL** — JOIN / CTE / Window Functions / CASE WHEN / INSERT...SELECT
- **Python** — pymysql 批量入库 / pyecharts 可视化

## 项目结构

```
ecommerce-dw/
├── sql/
│   ├── 01_create_ods.sql      # 建库建表
│   ├── 02_dwd.sql             # 清洗 + 维度退化
│   ├── 03_dws.sql             # 按用户/商品/日期聚合
│   ├── 04_ads_funnel.sql      # 转化漏斗
│   ├── 05_ads_rfm.sql         # RFM 用户价值分层
│   └── 06_ads_other.sql       # 活跃分布 / TOP 商品 / 复购率
├── scripts/
│   ├── gen_mock_data.py       # 生成模拟行为数据
│   ├── load_data.py           # CSV → MySQL 批量入库
│   └── visualization.py       # 从 ADS 表读取 → 生成图表
├── data/                      # 原始数据（.gitignore）
├── output/                    # 可视化结果（.gitignore）
├── .gitignore
├── README.md
└── requirements.txt
```

## 数据分层

| 层 | 表 | 粒度 |
|---|---|---|
| ODS | ods_user_behavior | 原始一行 = 一次行为 |
| DWD | dwd_user_behavior | 清洗后一行 = 一次行为 |
| DWS | dws_user_day / dws_item_day / dws_user_summary | 用户日 / 商品日 / 用户生命周期 |
| ADS | ads_funnel_overall / ads_rfm_segment / ... | 业务指标粒度 |

## 本地运行

```bash
python scripts/gen_mock_data.py        # 生成模拟数据
# MySQL 中执行 sql/01_create_ods.sql   # 建库建表
python scripts/load_data.py            # 批量入库
# DBeaver 中依次执行 sql/02~06         # 分层加工 + 分析
python scripts/visualization.py        # 生成可视化图表
```

## 数据集说明

使用天池电商用户行为数据集（模拟版），字段：user_id, item_id, category_id, behavior_type (pv/fav/cart/buy), timestamp。数据集不含金额维度，故 RFM 分层采用 R+F 二维。
