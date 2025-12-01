-- BASE LAYER: one row per order
CREATE OR REPLACE VIEW `steam-form-479809-a3.OlistProject.vw_kpi_base` AS
WITH item_rollup AS (
  SELECT
    oi.order_id,
    SUM(oi.price)         AS price_sum,
    SUM(oi.freight_value) AS freight_sum
  FROM `steam-form-479809-a3.OlistProject.avw_order_item_dataset` AS oi
  GROUP BY oi.order_id
),
payment_rollup AS (
  SELECT
    p.order_id,
    SUM(p.payment_value) AS paid_sum
  FROM `steam-form-479809-a3.OlistProject.vw_olist_payment_cleaned` AS p
  GROUP BY p.order_id
)
SELECT
  o.order_id,
  o.customer_id,
  DATE_TRUNC(DATE(o.purchase_timestamp), MONTH) AS order_month,
  o.order_status,
  ir.price_sum,
  ir.freight_sum,
  COALESCE(ir.price_sum, 0) + COALESCE(ir.freight_sum, 0) AS gmv_defined,
  pr.paid_sum
FROM `steam-form-479809-a3.OlistProject.vw_orders_cleaned` AS o
LEFT JOIN item_rollup   AS ir ON ir.order_id = o.order_id
LEFT JOIN payment_rollup AS pr ON pr.order_id = o.order_id
WHERE o.order_status IN ('approved','invoiced','shipped','delivered');
