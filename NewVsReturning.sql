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



-- ## New customers By State (Oct/Nov 2017) using customer_unique_id
WITH base_with_state AS (
  SELECT
    c.customer_unique_id,
    c.customer_state,
    b.order_id,
    DATE_TRUNC(DATE(b.order_month),MONTH) AS order_month,
    GMV_defined, 
    total_freight_value,
    total_price
  FROM `steam-form-479809-a3.OlistProject.base_layer` AS b
  JOIN `steam-form-479809-a3.OlistProject.vw_customers_cleaned` AS c
  ON b.customer_id = c.customer_id
  WHERE b.order_status IN ('delivered','shipped','invoiced','approved')
),
first_purchase AS (
  SELECT
    customer_unique_id,
    MIN(order_month) AS first_order_month
  FROM base_with_state
  GROUP BY customer_unique_id
),
tagged AS(
  SELECT
  b.customer_unique_id,
  b.customer_state,
  b.order_month,
  b.order_id,
  b.GMV_defined,
  CASE
    WHEN b.order_month = fp.first_order_month THEN 'NEW'
    WHEN b.order_month > fp.first_order_month THEN 'RETURNING'
    ELSE 'UNKNOWN'
  END AS customer_type
  FROM base_with_state AS b
  JOIN first_purchase AS fp
  ON b.customer_unique_id = fp.customer_unique_id
  WHERE b.order_month IN (DATE '2017-10-01', DATE '2017-11-01')
)
SELECT 
  order_month,
  customer_state,
  COUNT(DISTINCT customer_unique_id) AS new_customers_state,
  COUNT(DISTINCT order_id) AS new_orders_state,
  SUM(GMV_defined) AS GMV_state,
  SAFE_DIVIDE(SUM(GMV_defined), COUNT(DISTINCT order_id)) AS AOV
FROM tagged
WHERE customer_type = 'NEW'
GROUP BY order_month,customer_state
ORDER BY order_month,new_orders_state DESC


-- Deliverable 3: New GMV/AOV (Oct/Nov 2017) 

WITH base_with_person AS (
  SELECT
    DATE_TRUNC(DATE(b.order_month), MONTH) AS order_month,
    b.order_id,
    c.customer_unique_id,
    b.gmv_defined,
    c.customer_state
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
    b.customer_state,
    CASE
      WHEN b.order_month = fp.first_order_month THEN 'NEW'
      WHEN b.order_month > fp.first_order_month THEN 'RETURNING'
      ELSE 'UNKNOWN'
    END AS cust_type
  FROM base_with_person b
  JOIN first_purchase fp
    ON b.customer_unique_id = fp.customer_unique_id
  WHERE b.order_month IN (DATE '2017-10-01', DATE '2017-11-01')
  AND b.customer_state IS NOT NULL
),

state_new AS (
  SELECT
  customer_state,
  COUNT(DISTINCT IF(order_month = DATE '2017-10-01', order_id,NULL)) AS  new_orders_oct,
  COUNT(DISTINCT IF(order_month = DATE '2017-11-01', order_id,NULL)) AS  new_orders_nov,

  SUM(IF(order_month = DATE '2017-10-01', GMV_defined, 0)) AS new_gmv_oct,
  SUM(IF(order_month = DATE '2017-11-01', GMV_defined, 0)) AS new_gmv_nov,

  COUNT(DISTINCT IF(order_month = DATE '2017-10-01', customer_unique_id,NULL)) AS new_customer_oct,
  COUNT(DISTINCT IF(order_month = DATE '2017-11-01', customer_unique_id, NULL)) AS new_customer_nov,

  SAFE_DIVIDE(
    SUM(IF(order_month = DATE '2017-10-01', gmv_defined,0)),
    NULLIF(COUNT(DISTINCT IF(order_month =DATE '2017-10-01',order_id, NULL)),0)
  ) AS new_aov_oct,
  SAFE_DIVIDE(
    SUM(IF(order_month = DATE '2017-11-01', gmv_defined,0)),
    NULLIF(COUNT(DISTINCT IF(order_month =DATE '2017-11-01',order_id, NULL)),0)
  ) AS new_aov_nov
  FROM tagged
  WHERE cust_type = 'NEW'
  GROUP BY customer_state
)

SELECT
  customer_state,
  new_orders_oct, new_orders_nov,
  (new_orders_nov - new_orders_oct) AS delta_new_orders,
  new_gmv_oct, new_gmv_nov,
  (new_gmv_nov - new_gmv_oct) AS delta_new_gmv,
  SAFE_DIVIDE(new_gmv_oct, NULLIF(new_orders_oct, 0)) AS new_aov_oct,
  SAFE_DIVIDE(new_gmv_nov, NULLIF(new_orders_nov, 0)) AS new_aov_nov,
  SAFE_DIVIDE(new_gmv_nov, NULLIF(new_orders_nov, 0))
  - SAFE_DIVIDE(new_gmv_oct, NULLIF(new_orders_oct, 0)) AS delta_new_aov
FROM state_new
ORDER BY delta_new_orders DESC;
