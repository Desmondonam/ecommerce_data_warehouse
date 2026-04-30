
  
  create view "warehouse"."marts_staging"."stg_sellers__dbt_tmp" as (
    with source as (
    select * from "warehouse"."raw"."olist_sellers_dataset"
),

renamed as (
    select
        seller_id,
        seller_zip_code_prefix                      as zip_code_prefix,
        lower(trim(seller_city))                    as city,
        upper(trim(seller_state))                   as state
    from source
)

select * from renamed
  );
