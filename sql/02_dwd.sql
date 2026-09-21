-- ============================================================
-- 02_dwd.sql
-- 作用：DWD 明细层 —— 清洗 + 维度退化（从时间戳里拆出日期/小时/星期）
-- 前置：01 已执行，且数据已通过 Python 脚本导入 ods_user_behavior
-- ============================================================

USE ecommerce_dw;

-- 先确认 ODS 里已经有数据（行数应该是几十万~百万级，0 说明导入没跑）
SELECT COUNT(*) AS ods行数_导入前检查 FROM ods_user_behavior;

DROP TABLE IF EXISTS dwd_user_behavior;

-- 1. 建 DWD 明细表：一行 = 用户对商品的一次行为（清洗后）
CREATE TABLE dwd_user_behavior (
    user_id       INT          NOT NULL COMMENT '用户ID',
    item_id       INT          NOT NULL COMMENT '商品ID',
    category_id   INT          NOT NULL COMMENT '类目ID',
    behavior_type VARCHAR(10)  NOT NULL COMMENT 'pv/fav/cart/buy',
    behavior_time DATETIME     NOT NULL COMMENT '精确到秒的行为时间',
    dt            DATE         NOT NULL COMMENT '行为日期（退化维度）',
    hr            TINYINT      NOT NULL COMMENT '小时 0-23',
    weekday_cn    VARCHAR(8)   NOT NULL COMMENT '星期（中文）',
    is_weekend    TINYINT      NOT NULL COMMENT '是否周末：1是 0否',
    KEY idx_user_dt (user_id, dt),
    KEY idx_dt (dt),
    KEY idx_item (item_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'DWD层-用户行为明细表';

-- 2. 从 ODS 清洗加工灌入 DWD
--    清洗动作：过滤非法行为类型、过滤空时间（本数据很干净，主要演示规范动作）
--    加工动作：时间拆出 日期/小时/星期/是否周末 —— 这就是"维度退化"
INSERT INTO dwd_user_behavior
SELECT
    user_id,
    item_id,
    category_id,
    behavior_type,
    behavior_time,
    DATE(behavior_time)                                        AS dt,
    HOUR(behavior_time)                                        AS hr,
    CASE DAYOFWEEK(behavior_time)
        WHEN 1 THEN '星期日'
        WHEN 2 THEN '星期一'
        WHEN 3 THEN '星期二'
        WHEN 4 THEN '星期三'
        WHEN 5 THEN '星期四'
        WHEN 6 THEN '星期五'
        WHEN 7 THEN '星期六'
    END                                                        AS weekday_cn,
    CASE WHEN DAYOFWEEK(behavior_time) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM ods_user_behavior
WHERE behavior_type IN ('pv', 'fav', 'cart', 'buy')
  AND behavior_time IS NOT NULL;

-- 3. 验证：行数应该和 ODS 一致或略少（被过滤的脏数据）
SELECT
    (SELECT COUNT(*) FROM ods_user_behavior)               AS ods行数,
    (SELECT COUNT(*) FROM dwd_user_behavior)               AS dwd行数;

-- 4. 抽样看看清洗结果
SELECT * FROM dwd_user_behavior ORDER BY behavior_time LIMIT 10;

-- ============================================================
-- 实现说明：
-- 1) 维度退化：把日期、小时等维度信息直接放进事实表，避免每次分析都
--    重复计算日期函数，空间换时间。
-- 2) DWD 职责：清洗（去脏/去重/格式统一）+ 规范字段名 + 维度退化，
--    不做聚合。输入多少行，输出约多少行。
-- ============================================================
