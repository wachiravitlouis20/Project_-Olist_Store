-- ##AOV SQL Query
-- AOV by primary payment method (credit_card vs boleto)
WITH pay_primary AS (
  SELECT order_id, payment_type
  FROM (
    SELECT
      p.order_id,
      p.payment_type,
      p.payment_value,
      ROW_NUMBER() OVER(
        PARTITION BY p.order_id
        ORDER BY p.payment_value DESC, p.payment_type
      ) AS rn
    FROM `steam-form-479809-a3.OlistProject.vw_olist_payment_cleaned` p
    WHERE p.payment_type IN ('credit_card','boleto')
  )
  WHERE rn = 1  -- เลือกวิธีจ่ายที่มียอดมากสุดเป็น “หลัก” ต่อออเดอร์
)
SELECT
  pp.payment_type,
  COUNT(DISTINCT b.order_id) AS total_orders,
  SUM(b.gmv_defined)         AS gmv,
  ROUND(
    SAFE_DIVIDE(SUM(b.gmv_defined), COUNT(DISTINCT b.order_id))
  ,2) AS aov  -- นิยาม AOV = GMV / Orders
FROM `steam-form-479809-a3.OlistProject.vw_kpi_base` b
JOIN pay_primary pp USING (order_id)
WHERE b.order_month >= DATE '2017-06-01'
  AND b.order_month <  DATE '2017-12-01'
GROUP BY pp.payment_type
ORDER BY pp.payment_type;

-- CTE 2: คำนวณค่าชี้วัดด้านการขนส่ง
logistics_kpis AS (
    SELECT
        AVG(o.delivery_days) AS avg_delivery_days
    FROM
        vw_orders_cleaned AS o
)

-- Query สุดท้าย: รวม KPI ทั้งหมดเข้าด้วยกัน
SELECT
    ROUND(s.total_revenue::numeric, 2) AS total_revenue,
    s.total_orders,
    -- คำนวณ AOV จากยอดรวมที่คำนวณไว้ล่วงหน้า
    ROUND((s.total_revenue / s.total_orders)::numeric, 2) AS average_order_value,
    ROUND(l.avg_delivery_days::numeric, 2) AS avg_delivery_days
FROM
    sales_kpis AS s,
    logistics_kpis AS l;

--## LTV by RFM Segment
WITH rfm_with_segments AS (

    WITH latest_date AS (
        SELECT MAX(purchase_timestamp) AS max_date FROM vw_orders_cleaned
    ),
    customer_rfm_raw AS (
        SELECT
            c.customer_unique_id,
            (SELECT max_date FROM latest_date) - MAX(o.purchase_timestamp::date) AS recency_days,
            COUNT(DISTINCT o.order_id) AS frequency,
            SUM(p.payment_value) AS monetary
        FROM
            vw_orders_cleaned AS o
            JOIN vw_customers_cleaned AS c ON c.customer_id = o.customer_id
            JOIN vw_olist_payment_cleaned AS p ON p.order_id = o.order_id
        GROUP BY
            c.customer_unique_id
    ),
    customer_rfm_scores AS (
        SELECT
            *,
            NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
            NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
            NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
        FROM
            customer_rfm_raw
    )
    SELECT
        *,
        r_score || '' || f_score || '' || m_score AS rfm_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 THEN 'VIP'
            WHEN r_score >= 4 AND f_score < 4 THEN 'New / Promising'
            WHEN r_score < 3 AND f_score >= 4 THEN 'At-Risk Customers'
            WHEN r_score < 3 AND f_score < 3 THEN 'Lost Customers'
            ELSE 'Others'
        END AS customer_segment
    FROM
        customer_rfm_scores
)

SELECT
    customer_segment,
    ROUND(AVG(monetary)::numeric, 2) AS avg_monetary_value,
    COUNT(*) AS number_of_customers
FROM
    rfm_with_segments
GROUP BY
    customer_segment
ORDER BY
    avg_monetary_value DESC;


--## Order Per Customer Group By Month
SELECT
  order_month,
  customer_id,
  COUNT(DISTINCT order_id) AS orders
FROM `steam-form-479809-a3.OlistProject.vw_kpi_base`
GROUP BY order_month, customer_id
ORDER BY order_month, customer_id;

--## CM and CM% (Proxy) Monthly
-- KPI รายเดือน: CM และ CM% (proxy)
-- ชั้นใน: สรุปยอดต่อเดือน
WITH monthly AS (
  SELECT
    /* TODO: เลือกเดือนจาก order_month ตรงๆ ไม่ใช้ EXTRACT */
    order_month,
    SUM(price_sum)   AS sum_price,
    SUM(freight_sum) AS sum_freight,
    SUM(gmv_defined) AS sum_gmv
  FROM `steam-form-479809-a3.OlistProject.vw_kpi_base`
  WHERE order_month >= DATE '2017-06-01'
    AND order_month <  DATE '2017-12-01'
  GROUP BY order_month
)
SELECT
  order_month,
  sum_price,
  sum_freight,
  sum_gmv,
  (sum_price - sum_freight)                                  AS cm_proxy,
  ROUND(SAFE_DIVIDE(sum_freight, NULLIF(sum_gmv, 0)),2)               AS freight_share,
  ROUND(SAFE_DIVIDE((sum_price - sum_freight), NULLIF(sum_gmv, 0)),2) AS cm_proxy_pct
FROM monthly
ORDER BY order_month;

----- Cross check cm_proxy_pct ≈ 1 − 2 × freight_share
SELECT
  order_month,
  sum_price,
  sum_freight,
  sum_gmv,
  (sum_price - sum_freight) AS cm_proxy,
  ROUND(SAFE_DIVIDE(sum_freight, sum_gmv), 4)               AS freight_share,
  ROUND(SAFE_DIVIDE((sum_price - sum_freight), sum_gmv), 4) AS cm_proxy_pct
FROM monthly
ORDER BY order_month;

--## KPI monthly
CREATE OR REPLACE VIEW `steam-form-479809-a3`.`OlistProject`.`vw_kpi_monthly`
AS
WITH
  m AS (
    SELECT
      order_month,
      COUNT(DISTINCT order_id) AS orders,
      SUM(gmv_defined) AS gmv,
      COUNT(DISTINCT customer_id) AS unique_customers,
      SAFE_DIVIDE(SUM(freight_sum), SUM(gmv_defined)) AS freight_share,
      (SUM(price_sum) - SUM(freight_sum)) AS cm_proxy
    FROM `steam-form-479809-a3`.`OlistProject`.`vw_kpi_base`
    WHERE order_month >= DATE '2017-06-01' AND order_month < DATE '2017-12-01'
    GROUP BY order_month
  )
SELECT
  order_month,
  orders,
  gmv,
  SAFE_DIVIDE(gmv, orders) AS aov,
  unique_customers,
  freight_share,
  cm_proxy,
  SAFE_DIVIDE(cm_proxy, gmv) AS cm_proxy_pct,
  SAFE_DIVIDE(
    gmv - LAG(gmv) OVER (ORDER BY order_month),
    LAG(gmv) OVER (ORDER BY order_month))
    AS mom_gmv_pct
FROM `m`
ORDER BY order_month;

--## GMV Bridge Additive
-- Bridge ถัดเดือน: แยกส่วน Orders vs AOV
WITH x AS (
  SELECT
    order_month,
    orders,
    gmv,
    SAFE_DIVIDE(gmv, orders) AS aov,
    LAG(orders) OVER(ORDER BY order_month) AS orders_prev,
    LAG(gmv)    OVER(ORDER BY order_month) AS gmv_prev,
    LAG(SAFE_DIVIDE(gmv, orders)) OVER(ORDER BY order_month) AS aov_prev
  FROM `steam-form-479809-a3.OlistProject.vw_kpi_monthly`
)
SELECT
  order_month,
  gmv_prev,
  gmv,
  -- ส่วนที่มาจากการเปลี่ยนจำนวนออเดอร์ (คูณด้วย AOV ของเดือนก่อน)
  (orders - orders_prev) * aov_prev                         AS delta_from_orders,
  -- ส่วนที่มาจากการเปลี่ยน AOV (คูณด้วยจำนวนออเดอร์ของเดือนนี้)
  orders * (aov - aov_prev)                                 AS delta_from_aov,
  -- รวมประมาณการการเปลี่ยนแปลง GMV
  ((orders - orders_prev) * aov_prev) + (orders * (aov - aov_prev)) AS delta_gmv_est,
  SAFE_DIVIDE(((orders - orders_prev) * aov_prev),
              NULLIF(((orders - orders_prev) * aov_prev) + (orders * (aov - aov_prev)),0)) AS pct_from_orders,
  SAFE_DIVIDE((orders * (aov - aov_prev)),
              NULLIF(((orders - orders_prev) * aov_prev) + (orders * (aov - aov_prev)),0)) AS pct_from_aov
FROM x
WHERE orders_prev IS NOT NULL
ORDER BY order_month;

