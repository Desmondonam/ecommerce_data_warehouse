
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select gross_revenue
from "warehouse"."marts_marts"."fact_orders"
where gross_revenue is null



  
  
      
    ) dbt_internal_test