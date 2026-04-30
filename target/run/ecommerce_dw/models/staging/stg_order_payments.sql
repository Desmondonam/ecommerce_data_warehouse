
  
  create view "warehouse"."marts_staging"."stg_order_payments__dbt_tmp" as (
    with source as (
    select * from "warehouse"."raw"."olist_order_payments_dataset"
),

renamed as (
    select
        order_id,
        cast(payment_sequential as integer)         as payment_sequential,
        lower(trim(payment_type))                   as payment_type,
        cast(payment_installments as integer)       as payment_installments,
        cast(payment_value as numeric)              as payment_value
    from source
)

select * from renamed
  );
