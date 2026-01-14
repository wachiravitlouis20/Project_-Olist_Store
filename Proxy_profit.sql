WITH state_new_profit AS (
  SELECT
    customer_state,
    ## Orders
    COUNT(DISTINCT IF(order_month = DATE '2017-10-01',order_id,NULL)) AS new_orders_oct,
    COUNT(DISTINCT IF(order_month = DATE '2017-11-01',order_id, NULL)) AS new_orders_nov,
    ## GMV/Price/Freight
    SUM(IF(order_month = DATE '2017-10-01',gmv_defined,0)) AS new_gmv_oct,
    SUM(IF(order_month = DATE '2017-11-01',gmv_defined,0)) AS new_gmv_nov,

    SUM(IF(order_month = DATE '2017-10-01',total_price,0)) AS new_price_oct,
    SUM(IF(order_month = DATE '2017-11-01',total_price,0)) AS new_price_nov,

    SUM(IF(order_month = DATE '2017-10-01',total_freight_value,0)) AS new_freight_oct,
    SUM(IF(order_month = DATE '2017-11-01',total_freight_value,0)) AS new_freight_nov,

  FROM `steam-form-479809-a3.OlistProject.vw_tagged_orders`
  WHERE cust_type = 'NEW'
    AND customer_state IS NOT NULL
    AND order_month IN (DATE '2017-10-01', DATE '2017-11-01')
  GROUP BY customer_state
)

SELECT
  customer_state,

  -- Growth (NEW)
  new_orders_oct, new_orders_nov,
  (new_orders_nov - new_orders_oct) AS delta_new_orders,

  new_gmv_oct, new_gmv_nov,
  (new_gmv_nov - new_gmv_oct)       AS delta_new_gmv,

  -- AOV (NEW)
  SAFE_DIVIDE(new_gmv_oct, NULLIF(new_orders_oct, 0)) AS new_aov_oct,
  SAFE_DIVIDE(new_gmv_nov, NULLIF(new_orders_nov, 0)) AS new_aov_nov,
  SAFE_DIVIDE(new_gmv_nov, NULLIF(new_orders_nov, 0))
  - SAFE_DIVIDE(new_gmv_oct, NULLIF(new_orders_oct, 0)) AS delta_new_aov,

  -- Profitability: Freight Share
  SAFE_DIVIDE(new_freight_oct, NULLIF(new_gmv_oct, 0)) AS freight_share_oct,
  SAFE_DIVIDE(new_freight_nov, NULLIF(new_gmv_nov, 0)) AS freight_share_nov,
  SAFE_DIVIDE(new_freight_nov, NULLIF(new_gmv_nov, 0))
  - SAFE_DIVIDE(new_freight_oct, NULLIF(new_gmv_oct, 0)) AS delta_freight_share,

  -- Profitability: CM Proxy & CM% Proxy
  (new_price_oct - new_freight_oct) AS cm_proxy_oct,
  (new_price_nov - new_freight_nov) AS cm_proxy_nov,
  (new_price_nov - new_freight_nov) - (new_price_oct - new_freight_oct) AS delta_cm_proxy,

  SAFE_DIVIDE((new_price_oct - new_freight_oct), NULLIF(new_gmv_oct, 0)) AS cm_proxy_pct_oct,
  SAFE_DIVIDE((new_price_nov - new_freight_nov), NULLIF(new_gmv_nov, 0)) AS cm_proxy_pct_nov,
  SAFE_DIVIDE((new_price_nov - new_freight_nov), NULLIF(new_gmv_nov, 0))
  - SAFE_DIVIDE((new_price_oct - new_freight_oct), NULLIF(new_gmv_oct, 0)) AS delta_cm_proxy_pct

FROM state_new_profit
ORDER BY delta_new_orders DESC;
