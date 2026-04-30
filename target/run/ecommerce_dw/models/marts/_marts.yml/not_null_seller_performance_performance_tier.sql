
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select performance_tier
from "warehouse"."marts_marts"."seller_performance"
where performance_tier is null



  
  
      
    ) dbt_internal_test