-- ============================================================
-- 06_ads_other.sql
-- 作用：ADS 应用层 —— ③ 时段活跃 ④ TOP商品/类目 ⑤ 复购率
-- ============================================================

USE ecommerce_dw;

-- ------------------------------------------------------------
-- 1. 24 小时活跃分布（几点逛淘宝的人最多？）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_hourly_active;
CREATE TABLE ads_hourly_active AS
SELECT
    hr,
    COUNT(*)             AS pv_total,
    COUNT(DISTINCT user_id) AS uv
FROM dwd_user_behavior
WHERE behavior_type = 'pv'
GROUP BY hr
ORDER BY hr;

SELECT * FROM ads_hourly_active;

-- ------------------------------------------------------------
-- 2. TOP 10 商品（按购买用户数排名，不是次数——防刷单口径）
-- ------------------------------------------------------------
SELECT
    b.item_id,
    MAX(b.category_id)                          AS category_id,
    COUNT(DISTINCT b.user_id)                   AS buy_uv,
    COUNT(*)                                    AS buy_times,
    RANK() OVER (ORDER BY COUNT(DISTINCT b.user_id) DESC) AS 销量排名
FROM dwd_user_behavior b
WHERE b.behavior_type = 'buy'
GROUP BY b.item_id
ORDER BY buy_uv DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 3. TOP 10 类目（按购买次数）
-- ------------------------------------------------------------
SELECT
    category_id,
    SUM(behavior_type = 'pv')   AS pv_cnt,
    SUM(behavior_type = 'buy')  AS buy_cnt,
    COUNT(DISTINCT user_id)     AS buy_uv
FROM dwd_user_behavior
GROUP BY category_id
ORDER BY buy_cnt DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 4. 整体复购率 = 购买>=2次的用户数 / 购买过的用户数
--    复购率是电商健康度的核心指标
-- ------------------------------------------------------------
WITH buy_user AS (
    SELECT user_id, COUNT(*) AS buy_times
    FROM dwd_user_behavior
    WHERE behavior_type = 'buy'
    GROUP BY user_id
)
SELECT
    COUNT(*)                                                       AS 购买用户数,
    SUM(CASE WHEN buy_times >= 2 THEN 1 ELSE 0 END)                AS 复购用户数,
    ROUND(SUM(CASE WHEN buy_times >= 2 THEN 1 ELSE 0 END) * 100
          / COUNT(*), 2)                                          AS 复购率pct
FROM buy_user;

-- ------------------------------------------------------------
-- 5. 每日复购率趋势
-- ------------------------------------------------------------
WITH daily_buy AS (
    SELECT user_id, dt, COUNT(*) AS times
    FROM dwd_user_behavior
    WHERE behavior_type = 'buy'
    GROUP BY user_id, dt
)
SELECT
    dt,
    COUNT(*)                                                   AS 当日购买用户,
    SUM(times >= 2)                                            AS 当日多次购买用户,
    ROUND(SUM(times >= 2) * 100 / COUNT(*), 2)                 AS 当日复购率pct
FROM daily_buy
GROUP BY dt
ORDER BY dt;

-- ============================================================
-- 可扩展分析：
-- - 次日留存率：dws_user_day 自连接 a.user_id=b.user_id AND a.dt+1=b.dt
-- - 加购未买榜：dws_item_day 中 cart_cnt 高 buy_cnt 低，按差值排序
-- ============================================================
