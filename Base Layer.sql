CREATE OR REPLACE VIEW `steam-form-479809-a3.OlistProject.base_layer` AS
WITH item_rollup AS(
  SELECT 
    oi.order_id,
    SUM(oi.price) AS total_price,
    SUM(oi.freight_value) AS total_freight_value
  FROM `steam-form-479809-a3.OlistProject.avw_order_item_dataset` oi
  GROUP BY oi.order_id # Group by order id ไม่ซ้ำกัน
),
payment_rollup AS(
  SELECT
    p.order_id,
    SUM(p.payment_value) AS total_payment_value
  FROM `steam-form-479809-a3.OlistProject.vw_olist_payment_cleaned` p
  GROUP BY p.order_id # Group by order id ไม่ซ้ำกัน
)
SELECT  
  o.order_id,
  o.customer_id,
  DATETIME_TRUNC(purchase_timestamp, MONTH) AS order_month,
  o.order_status,
  pr.total_payment_value,
  ir.total_price,
  ir.total_freight_value,
  COALESCE(ir.total_price,0) + COALESCE(ir.total_freight_value, 0) AS GMV_defined
FROM `steam-form-479809-a3.OlistProject.vw_orders_cleaned` o
LEFT JOIN payment_rollup pr ON o.order_id = pr.order_id
LEFT JOIN item_rollup ir ON o.order_id = ir.order_id
WHERE o.order_status IN ('delivered', 'shipped', 'approved','invoiced')
ORDER BY o.order_id
