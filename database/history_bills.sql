-- 宿舍 AA 记账：历史账单表
-- 适用版本：MySQL 8.0.16+
-- 前置条件：人员表已经存在，且 people.id 的类型为 INT UNSIGNED。

CREATE TABLE IF NOT EXISTS `bills` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '账单ID',
    `bill_year` SMALLINT UNSIGNED NOT NULL COMMENT '账单年份',
    `bill_month` TINYINT UNSIGNED NOT NULL COMMENT '账单月份（1-12）',
    `total_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT '账单总金额',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bills_year_month` (`bill_year`, `bill_month`),
    CONSTRAINT `chk_bills_year` CHECK (`bill_year` BETWEEN 1 AND 9999),
    CONSTRAINT `chk_bills_month` CHECK (`bill_month` BETWEEN 1 AND 12),
    CONSTRAINT `chk_bills_total_amount` CHECK (`total_amount` >= 0)
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '历史账单主表';

CREATE TABLE IF NOT EXISTS `bill_details` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '账单明细ID',
    `bill_id` BIGINT UNSIGNED NOT NULL COMMENT '账单ID',
    `people_id` INT UNSIGNED NOT NULL COMMENT '人员ID',
    `water_fee` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT '水费',
    `electricity_fee` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT '电费',
    `phone_fee` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT '话费',
    `total_amount` DECIMAL(12, 2)
        GENERATED ALWAYS AS (`water_fee` + `electricity_fee` + `phone_fee`) STORED
        COMMENT '个人总计（水费+电费+话费）',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bill_details_bill_people` (`bill_id`, `people_id`),
    KEY `idx_bill_details_people_id` (`people_id`),
    CONSTRAINT `fk_bill_details_bill`
        FOREIGN KEY (`bill_id`) REFERENCES `bills` (`id`)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT `fk_bill_details_people`
        FOREIGN KEY (`people_id`) REFERENCES `people` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `chk_bill_details_water_fee` CHECK (`water_fee` >= 0),
    CONSTRAINT `chk_bill_details_electricity_fee` CHECK (`electricity_fee` >= 0),
    CONSTRAINT `chk_bill_details_phone_fee` CHECK (`phone_fee` >= 0)
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '历史账单人员明细表';

-- ---------------------------------------------------------------------------
-- 保存账单事务示例
-- 将示例中的年份、月份、人员ID和金额替换为实际参数后执行。
-- 账单总计在所有明细写入后由数据库重新汇总，避免信任前端传入的总计。
-- ---------------------------------------------------------------------------
/*
START TRANSACTION;

INSERT INTO `bills` (`bill_year`, `bill_month`, `total_amount`)
VALUES (2026, 8, 0.00);

SET @new_bill_id = LAST_INSERT_ID();

INSERT INTO `bill_details`
    (`bill_id`, `people_id`, `water_fee`, `electricity_fee`, `phone_fee`)
VALUES
    (@new_bill_id, 1, 16.00, 35.50, 10.00),
    (@new_bill_id, 2, 16.00, 42.50, 10.00);

UPDATE `bills` AS b
SET b.`total_amount` = (
    SELECT COALESCE(SUM(d.`total_amount`), 0.00)
    FROM `bill_details` AS d
    WHERE d.`bill_id` = b.`id`
)
WHERE b.`id` = @new_bill_id;

COMMIT;
*/

-- ---------------------------------------------------------------------------
-- 历史账单列表：按年月倒序查询
-- ---------------------------------------------------------------------------
/*
SELECT b.`id`,b.`bill_year`, b.`bill_month`,b.`total_amount`,b.`created_at`,b.`updated_at`FROM `bills` AS b ORDER BY b.`bill_year` DESC, b.`bill_month` DESC;
*/

-- ---------------------------------------------------------------------------
-- 账单详情：把 @target_bill_id 替换为需要查询的账单ID
-- ---------------------------------------------------------------------------
/*
SET @target_bill_id = 1;

SELECT
    b.`id` AS `bill_id`,
    b.`bill_year`,
    b.`bill_month`,
    b.`total_amount` AS `bill_total_amount`,
    p.`id` AS `people_id`,
    p.`name` AS `people_name`,
    d.`water_fee`,
    d.`electricity_fee`,
    d.`phone_fee`,
    d.`total_amount` AS `people_total_amount`
FROM `bills` AS b
JOIN `bill_details` AS d ON d.`bill_id` = b.`id`
JOIN `people` AS p ON p.`id` = d.`people_id`
WHERE b.`id` = @target_bill_id
ORDER BY d.`id`;
*/

-- ---------------------------------------------------------------------------
-- 总计一致性校验：is_consistent 为 1 表示主表总计与明细汇总一致
-- ---------------------------------------------------------------------------
/*
SELECT
    b.`id` AS `bill_id`,
    b.`total_amount` AS `saved_total_amount`,
    COALESCE(SUM(d.`total_amount`), 0.00) AS `calculated_total_amount`,
    b.`total_amount` = COALESCE(SUM(d.`total_amount`), 0.00) AS `is_consistent`
FROM `bills` AS b
LEFT JOIN `bill_details` AS d ON d.`bill_id` = b.`id`
GROUP BY b.`id`, b.`total_amount`
ORDER BY b.`id` DESC;
*/

-- ---------------------------------------------------------------------------
-- 删除账单示例
-- bill_details 会通过 ON DELETE CASCADE 自动删除对应明细。
-- ---------------------------------------------------------------------------
/*
SET @target_bill_id = 1;

START TRANSACTION;
DELETE FROM `bills` WHERE `id` = @target_bill_id;
COMMIT;
*/
