
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select state
from "warehouse"."marts_staging"."stg_sellers"
where state is null



  
  
      
    ) dbt_internal_test