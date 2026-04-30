
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with child as (
    select seller_id as from_field
    from "warehouse"."marts_marts"."fact_orders"
    where seller_id is not null
),

parent as (
    select seller_id as to_field
    from "warehouse"."marts_staging"."stg_sellers"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



  
  
      
    ) dbt_internal_test