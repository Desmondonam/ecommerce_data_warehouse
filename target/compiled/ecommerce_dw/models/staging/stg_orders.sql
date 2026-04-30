with source as (
    select * from "warehouse"."raw"."olist_orders_dataset"
),

renamed as (
    select
        order_id,
        customer_id,
        lower(trim(order_status))                           as order_status,
        cast(order_purchase_timestamp as timestamp)         as purchased_at,
        cast(order_approved_at as timestamp)                as approved_at,
        cast(order_delivered_carrier_date as timestamp)     as carrier_delivered_at,
        cast(order_delivered_customer_date as timestamp)    as customer_delivered_at,
        cast(order_estimated_delivery_date as timestamp)    as estimated_delivery_at
    from source
)

select * from renamed