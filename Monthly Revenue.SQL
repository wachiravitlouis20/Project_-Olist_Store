SELECT
  order_month,
  SUM(total_payment_value) AS paid_amount,
  SUM(total_price)         AS revenue_ex_freight,
  SUM(total_freight_value) AS total_freight,
  SUM(gmv_defined)         AS gmv,
  SUM(total_payment_value) - SUM(gmv_defined) AS leak_amt,
  SAFE_DIVIDE(
    ABS(SUM(total_payment_value) - SUM(gmv_defined)),
    NULLIF(SUM(gmv_defined), 0)
  ) AS leak_pct
FROM `steam-form-479809-a3.OlistProject.base_layer`
WHERE order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;
