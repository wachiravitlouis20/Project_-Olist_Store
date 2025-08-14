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
