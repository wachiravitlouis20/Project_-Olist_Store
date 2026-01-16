WITH base AS (
  SELECT 
    order_month,
    order_id,
    customer_unique_id,
    customer_state,
    gmv_defined,
    total_price,
    total_freight_value
  FROM `steam-form-479809-a3.OlistProject.vw_tagged_orders`
  WHERE cust_type = 'NEW'
    AND order_month IN (DATE '2017-10-01', DATE '2017-11-01')
    AND customer_state IN ('PR','RS','MG')
),

-- 1) rollup จาก "ตารางรายการสินค้า" (1 แถวต่อ item) ให้เหลือ 1 แถวต่อ order
item_rollup AS (
  SELECT
    oi.order_id,
    COUNT(*) AS item_count,
    SUM(oi.price) AS items_price_sum,
    SUM(oi.freight_value) AS items_freight_sum,
    SAFE_DIVIDE(SUM(oi.price), COUNT(*)) AS avg_unit_price_order
  FROM `steam-form-479809-a3.OlistProject.avw_order_item_dataset` oi
  JOIN base b
    ON b.order_id = oi.order_id
  GROUP BY oi.order_id
),

-- 2) เอา rollup กลับมา join กับ base เพื่อได้ state/month (ยังคง 1 แถวต่อ order)
joined AS (
  SELECT
    b.customer_state,
    b.order_month,
    b.order_id,
    b.gmv_defined,
    b.total_price,
    b.total_freight_value,
    ir.item_count,
    ir.items_price_sum,
    ir.items_freight_sum,
    ir.avg_unit_price_order
  FROM base b
  JOIN item_rollup ir
    ON b.order_id = ir.order_id
)

-- 3) สรุประดับ state + month
SELECT
  customer_state,
  order_month,

  COUNT(DISTINCT order_id) AS orders,
  SUM(gmv_defined) AS gmv,
  SAFE_DIVIDE(SUM(gmv_defined), COUNT(DISTINCT order_id)) AS aov,

  AVG(item_count) AS avg_items_per_order,

  -- avg unit price แบบ weighted (ดีกว่า avg(avg_unit_price_order))
  SAFE_DIVIDE(SUM(items_price_sum), SUM(item_count)) AS avg_unit_price,

  -- เผื่อดูว่า freight ต่อชิ้น/ต่อ order เป็นยังไง
  SAFE_DIVIDE(SUM(items_freight_sum), SUM(item_count)) AS avg_freight_per_item,
  SAFE_DIVIDE(SUM(total_freight_value), COUNT(DISTINCT order_id)) AS avg_freight_per_order

FROM joined
GROUP BY customer_state, order_month
ORDER BY customer_state, order_month;
