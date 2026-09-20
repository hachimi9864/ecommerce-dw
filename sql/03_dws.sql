-- ============================================================
-- 03_dws.sql
-- 作用：DWS 汇总层 —— 按不同粒度轻度聚合，给上层 ADS 复用
-- 三张汇总表：用户日活 / 商品日汇总 / 用户生命周期宽表
-- ============================================================

USE ecommerce_dw;

-- ------------------------------------------------------------
-- 汇总表1：用户-日 粒度（每个用户每天一行）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dws_user_day;
CREATE TABLE dws_user_day AS
SELECT
    user_id,
    dt,
    SUM(behavior_type = 'pv')   AS pv_cnt,    -- 浏览次数
    SUM(behavior_type = 'fav')  AS fav_cnt,   -- 收藏次数
    SUM(behavior_type = 'cart') AS cart_cnt,  -- 加购次数
    SUM(behavior_type = 'buy')  AS buy_cnt,   -- 购买次数
    COUNT(*)                    AS total_cnt  -- 当天总行为数
FROM dwd_user_behavior
GROUP BY user_id, dt;

-- 给汇总表加索引（CTAS 建表不会自动带索引）
ALTER TABLE dws_user_day ADD INDEX idx_user (user_id);
ALTER TABLE dws_user_day ADD INDEX idx_dt (dt);

-- ------------------------------------------------------------
-- 汇总表2：商品-日 粒度（每个商品每天一行）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dws_item_day;
CREATE TABLE dws_item_day AS
SELECT
    item_id,
    MAX(category_id)            AS category_id, -- 同一商品类目固定，MAX 随便取一个
    dt,
    SUM(behavior_type = 'pv')   AS pv_cnt,
    SUM(behavior_type = 'fav')  AS fav_cnt,
    SUM(behavior_type = 'cart') AS cart_cnt,
    SUM(behavior_type = 'buy')  AS buy_cnt
FROM dwd_user_behavior
GROUP BY item_id, dt;

ALTER TABLE dws_item_day ADD INDEX idx_item (item_id);

-- ------------------------------------------------------------
-- 汇总表3：用户生命周期宽表（每个用户一行，历史累计）
-- 这是"宽表"思想：把一个实体的常用指标全部摊平成列
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dws_user_summary;
CREATE TABLE dws_user_summary AS
SELECT
    user_id,
    MIN(dt)                                                    AS first_dt,        -- 首次活跃日
    MAX(dt)                                                    AS last_dt,         -- 最近活跃日
    COUNT(DISTINCT dt)                                         AS active_days,     -- 活跃天数
    SUM(behavior_type = 'pv')                                  AS total_pv,
    SUM(behavior_type = 'fav')                                 AS total_fav,
    SUM(behavior_type = 'cart')                                AS total_cart,
    SUM(behavior_type = 'buy')                                 AS total_buy,
    MIN(CASE WHEN behavior_type = 'buy' THEN dt END)           AS first_buy_dt,    -- 首购日
    MAX(CASE WHEN behavior_type = 'buy' THEN dt END)           AS last_buy_dt      -- 末购日
FROM dwd_user_behavior
GROUP BY user_id;

ALTER TABLE dws_user_summary ADD PRIMARY KEY (user_id);

-- ------------------------------------------------------------
-- 验证
-- ------------------------------------------------------------
SELECT 'dws_user_day'     AS 表名, COUNT(*) AS 行数 FROM dws_user_day
UNION ALL
SELECT 'dws_item_day',     COUNT(*) FROM dws_item_day
UNION ALL
SELECT 'dws_user_summary', COUNT(*) FROM dws_user_summary;

-- 看几个用户的汇总数据感受一下
SELECT * FROM dws_user_summary WHERE total_buy > 0 ORDER BY total_buy DESC LIMIT 10;

-- ============================================================
-- 知识点：
-- 1) 技巧 SUM(behavior_type = 'pv')：MySQL 里条件成立=1 不成立=0，
--    比 SUM(CASE WHEN ... THEN 1 ELSE 0 END) 简洁。写标准 SQL 或 Hive
--    时仍要用 CASE WHEN，两种写法都要会。
-- 2) DWS 的价值：复用。上面三张表建一次，漏斗、RFM、留存全都从它们取数，
--    不用每次扫 100 万行明细，这就是分层的性能和口径统一意义。
-- ============================================================
