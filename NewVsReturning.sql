-- Deliverable 1: New vs Returning (Oct/Nov 2017) using customer_unique_id

WITH base_with_person AS (
  SELECT
    DATE_TRUNC(DATE(b.order_month), MONTH) AS order_month,
    b.order_id,
    c.customer_unique_id,
    b.gmv_defined
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
),

tagged AS (
  SELECT
    b.order_month,
    b.order_id,
    b.customer_unique_id,
    b.gmv_defined,
    CASE
      WHEN b.order_month = fp.first_order_month THEN 'NEW'
      WHEN b.order_month > fp.first_order_month THEN 'RETURNING'
      ELSE 'UNKNOWN'
    END AS cust_type
  FROM base_with_person b
  JOIN first_purchase fp
    ON b.customer_unique_id = fp.customer_unique_id
  WHERE b.order_month IN (DATE '2017-10-01', DATE '2017-11-01')
)

SELECT
  order_month,

  COUNT(DISTINCT IF(cust_type = 'NEW', customer_unique_id, NULL))       AS new_customers,
  COUNT(DISTINCT IF(cust_type = 'RETURNING', customer_unique_id, NULL)) AS returning_customers,
  COUNT(DISTINCT customer_unique_id)                                    AS unique_customers,

  COUNT(DISTINCT IF(cust_type = 'NEW', order_id, NULL))                 AS orders_from_new,
  COUNT(DISTINCT IF(cust_type = 'RETURNING', order_id, NULL))           AS orders_from_returning,
  COUNT(DISTINCT order_id)                                              AS total_orders,

  SUM(IF(cust_type = 'NEW', gmv_defined, 0))                            AS gmv_from_new,
  SUM(IF(cust_type = 'RETURNING', gmv_defined, 0))                      AS gmv_from_returning,
  SUM(gmv_defined)                                                      AS total_gmv

FROM tagged
GROUP BY order_month
ORDER BY order_month;
