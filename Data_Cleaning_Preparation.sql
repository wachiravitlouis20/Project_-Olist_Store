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

-- ## 
select distinct payment_type 
from olist_order_payments_dataset;
