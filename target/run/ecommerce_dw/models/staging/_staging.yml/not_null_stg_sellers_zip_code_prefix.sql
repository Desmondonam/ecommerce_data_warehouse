
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select zip_code_prefix
from "warehouse"."marts_staging"."stg_sellers"
where zip_code_prefix is null



  
  
      
    ) dbt_internal_test