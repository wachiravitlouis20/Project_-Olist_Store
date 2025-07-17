--Q1: How much that 5 states (Customer States) that generate total revenue by month?

with filtered_order as ( 
	select order_id, order_purchase_timestamp
	from olist_orders_dataset
	where order_status not in ('unavailable','canceled')
), 
order_payments as (
	select fo.order_purchase_timestamp, opd.payment_value
	from filtered_order as fo
	JOIN olist_order_payments_dataset AS opd on fo.order_id = opd.order_id
)
select EXTRACT(YEAR from order_purchase_timestamp::timestamp) as sales_year,
	EXTRACT(month from order_purchase_timestamp::timestamp) as sales_month,
	SUM(payment_value) AS total_revenue
from order_payments
group by
sales_year, 
sales_month
ORDER BY
  sales_year, 
sales_month;

-- Q2 : "What is the total revenue generated per month and per year by the top 5 customer states?""

select co.customer_state, 
sum(po.payment_value) as total_revenue
	from 
		olist_orders_dataset as od
		join olist_customers_dataset as co
		on co.customer_id  = od.customer_id  
		join olist_order_payments_dataset as po
		on od.order_id = po.order_id
		where 
			order_status not in ('canceled','unavailable')
group by 
	co.customer_state
order by 
	total_revenue desc
		limit 5;

-- Q3 : What are the monthly growth rates for these 5 states?
  
WITH
  monthly_sales_by_state AS (
    SELECT
      co.customer_state,
      EXTRACT(YEAR FROM od.order_purchase_timestamp::timestamp) AS sales_year,
      EXTRACT(MONTH FROM od.order_purchase_timestamp::timestamp) AS sales_month,
      SUM(po.payment_value) AS total_revenue
    FROM
      olist_orders_dataset AS od
      JOIN olist_customers_dataset AS co ON od.customer_id = co.customer_id
      JOIN olist_order_payments_dataset AS po ON po.order_id = od.order_id
    WHERE
      od.order_status NOT IN ('unavailable', 'canceled')
    GROUP BY
      co.customer_state,
      sales_year,
      sales_month
  ),
  add_previous_month_sales AS (
    SELECT
      *,
      LAG(total_revenue, 1) OVER (
        PARTITION BY customer_state
        ORDER BY sales_year, sales_month
      ) AS previous_month_revenue
    FROM
      monthly_sales_by_state
  )

SELECT
  customer_state,
  sales_year,
  sales_month,
  total_revenue,
  previous_month_revenue,
  CASE
    WHEN previous_month_revenue IS NULL OR previous_month_revenue = 0 THEN NULL
    ELSE 
    ROUND(
        (((total_revenue - previous_month_revenue) / previous_month_revenue) * 100.0)::numeric,
        2
      )
  END AS growth_rate_pct
FROM
  add_previous_month_sales
WHERE
  customer_state IN ('SP', 'RJ', 'MG', 'RS', 'PR')
ORDER BY
  customer_state,
  sales_year,
  sales_month;
