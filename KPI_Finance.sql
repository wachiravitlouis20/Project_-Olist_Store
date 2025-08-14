-- ##AOV SQL Query
SELECT
    payment_type,
    ROUND(
        (SUM(payment_value) / COUNT(DISTINCT order_id))::numeric,
        2
    ) AS aov,
    -- การนับจำนวนออเดอร์ในแต่ละกลุ่ม
    COUNT(DISTINCT order_id) AS total_orders
FROM
    vw_olist_payment_cleaned -- < ใช้ชื่อ View ของคุณ
WHERE
    payment_type IN ('credit_card', 'boleto')
GROUP BY
    payment_type;

--## AOV For เปรียบเทียบ (สำหรับ A/B Test)
SELECT
    payment_type,
    ROUND(
        (SUM(payment_value) / COUNT(DISTINCT order_id))::numeric,
        2
    ) AS aov,
    -- การนับจำนวนออเดอร์ในแต่ละกลุ่ม
    COUNT(DISTINCT order_id) AS total_orders
FROM
    vw_olist_payment_cleaned -- < ใช้ชื่อ View ของคุณ
WHERE
    payment_type IN ('credit_card', 'boleto')
GROUP BY
    payment_type;

-- ## Query for Executive Summary KPIs
-- CTE 1: คำนวณค่าชี้วัดด้านยอดขายและออเดอร์
WITH sales_kpis AS (
    SELECT
        SUM(p.payment_value) AS total_revenue,
        COUNT(DISTINCT p.order_id) AS total_orders
    FROM
        vw_olist_payment_cleaned AS p
),

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

-- ## Query: อัตราส่วนรายได้ต่อค่าขนส่ง (Revenue-to-Freight Ratio) แยกตามรัฐ
SELECT
    c.customer_state,
    CASE
        WHEN SUM(i.freight_value) > 0 THEN
            ROUND((SUM(i.price) / SUM(i.freight_value))::numeric, 2)
        ELSE
            0
    END AS revenue_to_freight_ratio,
    ROUND(SUM(i.price)::numeric, 2) AS total_revenue,
    ROUND(SUM(i.freight_value)::numeric, 2) AS total_freight
FROM
    vw_customers_cleaned AS c
JOIN
    vw_orders_cleaned AS o ON c.customer_id = o.customer_id
JOIN
    vw_order_items_cleaned AS i ON o.order_id = i.order_id
GROUP BY
    c.customer_state
ORDER BY
    revenue_to_freight_ratio DESC;
