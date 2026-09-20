-- ============================================================
-- 04_ads_funnel.sql
-- 作用：ADS 应用层 —— 电商核心分析①：转化漏斗
-- 漏斗口径：浏览UV → 收藏/加购UV → 购买UV
-- UV = 去重用户数（COUNT DISTINCT），不是行为次数
-- ============================================================

USE ecommerce_dw;

-- ------------------------------------------------------------
-- 1. 整体转化漏斗（整个统计周期一行）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_funnel_overall;
CREATE TABLE ads_funnel_overall AS
SELECT
    COUNT(DISTINCT CASE WHEN behavior_type = 'pv'  THEN user_id END) AS uv_pv,
    COUNT(DISTINCT CASE WHEN behavior_type IN ('fav','cart') THEN user_id END) AS uv_fav_cart,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS uv_buy
FROM dwd_user_behavior;

-- 查询：带逐级转化率（*100/100 让结果保持整数，避免 0.0300000001 浮点脏数）
SELECT
    uv_pv                                                              AS 浏览用户数,
    uv_fav_cart                                                        AS 收藏加购用户数,
    uv_buy                                                             AS 购买用户数,
    uv_fav_cart * 10000 / uv_pv / 100                                  AS 浏览到加购转化率,
    uv_buy     * 10000 / uv_fav_cart / 100                             AS 加购到购买转化率,
    uv_buy     * 10000 / uv_pv / 100                                   AS 整体转化率
FROM ads_funnel_overall;

-- ------------------------------------------------------------
-- 2. 每日漏斗（看转化率每天的波动趋势）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_funnel_daily;
CREATE TABLE ads_funnel_daily AS
SELECT
    dt,
    COUNT(DISTINCT CASE WHEN behavior_type = 'pv'  THEN user_id END) AS uv_pv,
    COUNT(DISTINCT CASE WHEN behavior_type IN ('fav','cart') THEN user_id END) AS uv_fav_cart,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS uv_buy
FROM dwd_user_behavior
GROUP BY dt;

SELECT
    dt,
    uv_pv                                                        AS 浏览UV,
    uv_fav_cart                                                  AS 收藏加购UV,
    uv_buy                                                       AS 购买UV,
    uv_fav_cart * 10000 / uv_pv / 100                            AS 浏览到加购_pct,
    uv_buy     * 10000 / uv_fav_cart / 100                       AS 加购到购买_pct,
    uv_buy     * 10000 / uv_pv / 100                             AS 整体_pct
FROM ads_funnel_daily
ORDER BY dt;

-- ============================================================
-- 面试要点：
-- 1) 为什么用 UV 而不是 PV/行为次数？答：业务关心"多少人"完成转化，
--    次数会被一个用户刷 100 次严重放大。
-- 2) 为什么把 fav 和 cart 合并？答：收藏和加购都是"购买意向"行为，
--    很多用户只收藏不加购（或反过来），合并更贴近意向漏斗的本意；
--    面试时主动说明"我也可以拆成四级漏斗"，体现口径意识。
-- 3) 转化率为什么会超过100%或很奇怪？检查口径：分母阶段用户未必经过
--    上一阶段（本周期买过的人可能上周期浏览的），严格漏斗要用
--    同批用户路径追踪（先发生pv再发生buy），那是"路径漏斗"，进阶版。
-- ============================================================
