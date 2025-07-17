--Q1: What are the 5 states (Customer States) that generate the highest total revenue?

SELECT
  co.customer_state,
  SUM(po.payment_value) AS total_revenue
FROM
  olist_orders_dataset AS od
  JOIN olist_customers_dataset AS co ON co.customer_id = od.customer_id
  JOIN olist_order_payments_dataset AS po ON od.order_id = po.order_id
WHERE
  od.order_status NOT IN ('canceled', 'unavailable')
-- เราต้องการยอดรวมของ "ทั้งรัฐ" จึงจัดกลุ่มตามรัฐเท่านั้น
GROUP BY
  co.customer_state
-- เรียงลำดับจาก "ยอดขายรวม" ที่คำนวณได้
ORDER BY
  total_revenue DESC
LIMIT 5;

-- Q2 : What are the 5 states (Customer States) that generate the highest total revenue?"

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
