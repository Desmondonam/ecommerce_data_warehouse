
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select seller_id
from "warehouse"."marts_marts"."seller_performance"
where seller_id is null



  
  
      
    ) dbt_internal_test