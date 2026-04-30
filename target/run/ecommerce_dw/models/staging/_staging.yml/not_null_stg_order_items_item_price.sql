
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select item_price
from "warehouse"."marts_staging"."stg_order_items"
where item_price is null



  
  
      
    ) dbt_internal_test