-- ============================================================
-- 01_create_ods.sql
-- 作用：建库 + ODS 原始数据层
-- 在 DBeaver 里打开本文件，整段选中 → Ctrl+Enter 执行
-- ============================================================

-- 1. 建库（utf8mb4 才能存中文）
CREATE DATABASE IF NOT EXISTS ecommerce_dw DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

USE ecommerce_dw;

-- 2. 删旧表（重复执行本脚本不会报错；会清空数据，学习阶段无所谓）
DROP TABLE IF EXISTS ods_user_behavior;

-- 3. ODS 层：用户行为原始表
--    字段和天池「淘宝用户行为数据集」完全一致，真实数据/模拟数据通用
CREATE TABLE ods_user_behavior (
    user_id       INT          NOT NULL COMMENT '用户ID',
    item_id       INT          NOT NULL COMMENT '商品ID',
    category_id   INT          NOT NULL COMMENT '商品类目ID',
    behavior_type VARCHAR(10)  NOT NULL COMMENT '行为类型：pv浏览/fav收藏/cart加购/buy购买',
    behavior_time DATETIME     NOT NULL COMMENT '行为发生时间',
    -- ODS 层也可以加索引：100万行没索引会慢得令人发指
    KEY idx_user (user_id),
    KEY idx_item (item_id),
    KEY idx_time (behavior_time),
    KEY idx_type (behavior_type)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'ODS层-淘宝用户行为原始表';

-- 4. 验证：表建好了（此时是空表，行数=0）
SELECT COUNT(*) AS ods行数 FROM ods_user_behavior;

-- ============================================================
-- 常见问题：
-- Q: 为什么不设自增主键？
-- A: ODS 原始日志表的每一行来自业务日志，用 (user_id, item_id, behavior_time)
--    天然标识一行，自增 id 在真实数仓里意义不大；加索引是为了查询速度。
-- Q: 真实数仓的 ODS 长这样吗？
-- A: 真实环境一般是 Hive/Iceberg 等大数据存储，按天分区（PARTITIONED BY dt）。
--    MySQL 里我们用普通表模拟，思想完全一样。
-- ============================================================
