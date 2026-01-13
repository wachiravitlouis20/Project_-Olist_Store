--## Create tagged order
CREATE OR REPLACE VIEW `steam-form-479809-a3.OlistProject.vw_tagged_orders` AS
WITH base_with_person AS (
  SELECT
    DATE_TRUNC(DATE(b.order_month), MONTH) AS order_month,
    b.order_id,
    c.customer_unique_id,
    c.customer_state,
    b.gmv_defined,
    b.total_price,
    b.total_freight_value
  FROM `steam-form-479809-a3.OlistProject.base_layer` b
  JOIN `steam-form-479809-a3.OlistProject.vw_customers_cleaned` c
    ON b.customer_id = c.customer_id
  WHERE b.order_status IN ('delivered','shipped','approved','invoiced')
),
first_purchase AS (
  SELECT
    customer_unique_id,
    MIN(order_month) AS first_order_month
  FROM base_with_person
  GROUP BY customer_unique_id
)
SELECT
  b.order_month,
  b.order_id,
  b.customer_unique_id,
  b.customer_state,
  b.gmv_defined,
  b.total_price,
  b.total_freight_value,
  CASE
    WHEN b.order_month = fp.first_order_month THEN 'NEW'
    WHEN b.order_month > fp.first_order_month THEN 'RETURNING'
    WHEN b.order_month < fp.first_order_month THEN 'DATA_ISSUE'
    ELSE 'DATA_ISSUE'
  END AS cust_type
FROM base_with_person b
JOIN first_purchase fp
  ON b.customer_unique_id = fp.customer_unique_id;
