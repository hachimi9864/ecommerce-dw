-- ============================================================
-- 05_ads_rfm.sql
-- 作用：ADS 应用层 —— 电商核心分析②：RFM 用户价值分层
-- R = Recency 最近一次购买距参照日多少天（越小越好）
-- F = Frequency 统计周期内购买次数（越大越好）
-- M = Monetary 消费金额 —— 本数据集【没有金额字段】，无法计算，
--     所以采用 R+F 二维分层（面试时主动讲这个数据局限，是加分项）
-- ============================================================

USE ecommerce_dw;

-- 参照日：数据集最后一天的次日（和天池 2017-11-25~12-03 对齐，即 12-04）
-- 用子查询自动取，真实数据/模拟数据都不用手改
SET @ref_date = (SELECT DATE_ADD(MAX(behavior_time), INTERVAL 1 DAY)
                 FROM dwd_user_behavior WHERE behavior_type = 'buy');

-- ------------------------------------------------------------
-- 1. 计算每个购买用户的 R、F
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_rfm_detail;
CREATE TABLE ads_rfm_detail AS
SELECT
    user_id,
    DATEDIFF(@ref_date, MAX(CASE WHEN behavior_type = 'buy' THEN behavior_time END)) AS recency,
    COUNT(CASE WHEN behavior_type = 'buy' THEN 1 END) AS frequency
FROM dwd_user_behavior
GROUP BY user_id
HAVING frequency > 0;   -- RFM 只给买过的用户分层；没买过的用户属于"潜在/流失召回"另一个模型

-- ------------------------------------------------------------
-- 2. 打分：NTILE(5) 窗口函数把用户按 R/F 各自均分成 5 档
--    R 越小越近 → 越该给高分 → 所以 R 用倒序
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_rfm_scored;
CREATE TABLE ads_rfm_scored AS
SELECT
    user_id,
    recency,
    frequency,
    6 - NTILE(5) OVER (ORDER BY recency)   AS r_score,  -- R最小→5分，最大→1分
    NTILE(5)     OVER (ORDER BY frequency) AS f_score   -- F最大→5分，最小→1分
FROM ads_rfm_detail;

-- ------------------------------------------------------------
-- 3. 分群：分数 >=4 记 1（高），否则记 0（低），拼成两位编码
--    11 重要价值 / 10 重要发展 / 01 重要保持 / 00 一般挽留
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ads_rfm_segment;
CREATE TABLE ads_rfm_segment AS
SELECT
    s.*,
    CONCAT(CASE WHEN r_score >= 4 THEN '1' ELSE '0' END,
           CASE WHEN f_score >= 4 THEN '1' ELSE '0' END) AS rf_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN '重要价值客户'
        WHEN r_score >= 4 AND f_score <  4 THEN '重要发展客户'
        WHEN r_score <  4 AND f_score >= 4 THEN '重要保持客户'
        ELSE '一般挽留客户'
    END AS segment
FROM ads_rfm_scored s;

-- ------------------------------------------------------------
-- 4. 结果：每群多少人、占比
-- ------------------------------------------------------------
SELECT
    segment                          AS 用户分群,
    COUNT(*)                         AS 用户数,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS 占比pct,
    ROUND(AVG(recency), 1)           AS 平均R_天,
    ROUND(AVG(frequency), 2)         AS 平均F_次
FROM ads_rfm_segment
GROUP BY segment
ORDER BY 用户数 DESC;

-- 抽看 20 个重要价值客户
SELECT * FROM ads_rfm_segment WHERE segment = '重要价值客户' LIMIT 20;

-- ============================================================
-- 面试高频问答：
-- Q: NTILE(5) 是什么？数据不均匀会怎样？
-- A: 按排序把行尽量均分成5组。若行数不能整除，前面的组多1行；
--    大量并列值也可能被切到相邻组。数据量小时可改用 CASE WHEN 阈值。
-- Q: 为什么用 @ref_date 而不是 CURRENT_DATE？
-- A: 数据集是2017年的历史数据，用今天算 R 所有人都是3000+天，全错。
--    数据分析必须"回到业务当时"，参照日是分析口径的一部分。
-- Q: 没有 M 怎么办？
-- A: 主动说明：① 若有订单金额表，LEFT JOIN 进来取 SUM(amount) 补齐 M；
--    ② 没有金额时用 R+F 二维分层是业内常见折中，不要假装算了 M。
-- Q: RFM 怎么落地？
-- A: 重要价值客户给VIP权益/新品首发；重要发展客户发券提频；
--    重要保持客户（很久没来但曾经高频）做召回推送；一般挽留低成本触达。
-- ============================================================
