-- Bronze stays in the bucket; this loads the working set into native tables.
-- Dataset: data-engineering-i2.toes_ugo_feliz_thomas_warehouse (europe-west1).
-- Why each table is native or external: docs/warehouse-tuning.md, section 1.

CREATE SCHEMA IF NOT EXISTS `data-engineering-i2.toes_ugo_feliz_thomas_warehouse`
OPTIONS (location = 'europe-west1');

-- Bronze, read in place from the bucket
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_orders`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/orders.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_order_items`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/order_items.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_product`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/product.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_review`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/review.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_product_reviews`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/product_reviews.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_customer_shipping`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/customer_shipping.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_shipping_details`
OPTIONS (format = 'CSV', uris = ['gs://data-engineering-i2-feliz/fallback/shipping_details.csv'], skip_leading_rows = 1, allow_quoted_newlines = true);
CREATE OR REPLACE EXTERNAL TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_clickstream`
WITH PARTITION COLUMNS (dt STRING)
OPTIONS (format = 'PARQUET', uris = ['gs://data-engineering-i2-feliz/bronze/clickstream/*'], hive_partition_uri_prefix = 'gs://data-engineering-i2-feliz/bronze/clickstream');

-- Working set, as native tables, untuned: the baseline every measurement is compared to
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_orders`;
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.product` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_product`;
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.review` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_review`;
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.product_reviews` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_product_reviews`;
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.customer_shipping` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_customer_shipping`;
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.shipping_details` AS SELECT * FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_shipping_details`;

-- order_items records no date of its own: it takes order_date from its order
CREATE OR REPLACE TABLE `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items` AS
SELECT i.order_id, i.p_id, i.qty, i.price_at_purchase, o.order_date
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.ext_order_items` AS i
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders` AS o USING (order_id);
