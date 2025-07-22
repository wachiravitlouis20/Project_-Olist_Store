-- ## check data.
select * 
  from olist_orders_dataset limit 10;


-- ## Check order status and find that unavailable and cancel shouldn't count in revenue.
select distinct order_status  
  from olist_orders_dataset;


-- ## Create clean view olist_order_dataset
create or REPLACE view vw_orders_cleaned as
select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::timestamp as purchase_timestamp,
    order_approved_at::timestamp as approved_at,
    order_delivered_carrier_date::timestamp as delivered_to_carrier_at,
    order_delivered_customer_date::timestamp as delivered_to_customer_at,
    order_estimated_delivery_date::timestamp as estimated_delivery_at,
    case
        when order_status = 'delivered'
        then order_delivered_customer_date::date - order_purchase_timestamp::date
        else null
    end as delivery_days
from
    olist_orders_dataset
where
    order_status not in ('unavailable', 'canceled');

-- ## Check Null Dupicate format and Clean olist_order_item_dataset
-- ## Check Null
select 
	count(*)
from 
	olist_order_items_dataset
where order_id is null
	  or product_id is null
	  or price is null;

-- ## Check Dupicate
select
	order_id,
    order_item_id,
    product_id,
    count(*) as check_dupicate
from olist_order_items_dataset
	group by
	order_id,
    order_item_id,
    product_id
   	having
   	count(*) > 1;
-- ## Check logical error (Price and Freight Shoud not below 0)
select 
	price,
	freight_value
from olist_order_items_dataset
where price <= 0 or freight_value <= 0;

--## Creat View table with clean data
create or replace view avw_order_item_dataset as
	select
	order_id,
	order_item_id,
	product_id,
	seller_id,
	shipping_limit_date::timestamp as ship_limit_date,
	price,
	freight_value
from
	olist_order_items_dataset;

