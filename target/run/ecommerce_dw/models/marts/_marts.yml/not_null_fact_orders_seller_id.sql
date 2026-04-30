
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select seller_id
from "warehouse"."marts_marts"."fact_orders"
where seller_id is null



  
  
      
    ) dbt_internal_test