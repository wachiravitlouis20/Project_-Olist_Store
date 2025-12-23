-- Deliverable 1: New vs Returning (Oct/Nov 2017) using customer_unique_id

WITH base_layer_cus AS (
  SELECT 
    c.customer_unique_id,
    b.order_id,
    DATE_TRUNC(DATE(b.order_month), MONTH) AS order_month,
    b.GMV_defined
  FROM `steam-form-479809-a3.OlistProject.base_layer` AS b
  JOIN `steam-form-479809-a3.OlistProject.vw_customers_cleaned` AS c
   ON b.customer_id = c.customer_id
  WHERE b.order_status IN ('delivered', 'shipped','invoiced','approved')
),
first_purchase AS(
  SELECT
    customer_unique_id,
    MIN(order_month) AS first_purchase_month
  FROM base_layer_cus
  GROUP BY customer_unique_id
),
tagged AS(
  SELECT 
    b.customer_unique_id,
    b.order_month,
    b.order_id,
    b.GMV_defined,
  CASE
    WHEN b.order_month = f.first_purchase_month THEN 'New'
    WHEN b.order_month > f.first_purchase_month THEN 'Returning'
    ELSE 'Unknown'
  END AS cust_type
  FROM base_layer_cus AS b
  JOIN first_purchase AS f
    ON b.customer_unique_id = f.customer_unique_id
  WHERE b.order_month IN (DATE '2017-10-01', DATE '2017-11-01')
)

SELECT
  order_month,

  COUNT(DISTINCT IF(cust_type = 'New', customer_unique_id, NULL))       AS new_customers,
  COUNT(DISTINCT IF(cust_type = 'Returning', customer_unique_id, NULL)) AS returning_customers,
  COUNT(DISTINCT customer_unique_id)                                    AS unique_customers,

  COUNT(DISTINCT IF(cust_type = 'New', order_id, NULL))                 AS orders_from_new,
  COUNT(DISTINCT IF(cust_type = 'Returning', order_id, NULL))           AS orders_from_returning,
  COUNT(DISTINCT order_id)                                              AS total_orders,

  SUM(IF(cust_type = 'New', GMV_defined, 0))                            AS gmv_from_new,
  SUM(IF(cust_type = 'Returning', GMV_defined, 0))                      AS gmv_from_returning,
  SUM(GMV_defined)                                                      AS total_gmv

FROM tagged
GROUP BY order_month
ORDER BY order_month;
