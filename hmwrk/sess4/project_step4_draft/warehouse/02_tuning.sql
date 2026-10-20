-- Tuned variants, built next to the untuned tables so both can be measured.
-- Results and the reason for each choice: docs/warehouse-tuning.md, section 2.

-- Kept: monthly partitions (37 of about 6,000 and 11,000 rows)
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders_p`
PARTITION BY DATE_TRUNC(order_date, MONTH) AS
SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders`;

CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p`
PARTITION BY DATE_TRUNC(order_date, MONTH) AS
SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items`;

-- Tried and not kept: daily partitions (1,096 of about 370 rows) saved 1.5% more
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_pd`
PARTITION BY order_date AS
SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items`;

-- Tried and not kept: clustering by product saved nothing on our questions
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_pc`
PARTITION BY DATE_TRUNC(order_date, MONTH)
CLUSTER BY p_id AS
SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items`;

CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.product_c`
CLUSTER BY p_id AS
SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.product`;
