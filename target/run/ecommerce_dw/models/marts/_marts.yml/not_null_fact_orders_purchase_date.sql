
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select purchase_date
from "warehouse"."marts_marts"."fact_orders"
where purchase_date is null



  
  
      
    ) dbt_internal_test