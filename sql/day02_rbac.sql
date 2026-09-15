SELECT CURRENT_ROLE();
CREATE ROLE data_engineer;
CREATE ROLE data_analyst;


-- Put DATA_ENGINEER under SYSADMIN
GRANT ROLE data_engineer TO ROLE SYSADMIN;

-- Document why we use the role hierarchy
COMMENT ON ROLE data_engineer IS
'Inherited into SYSADMIN so administrative and deployment privileges are managed through the role hierarchy rather than granted directly to an individual user.';

SHOW ROLES LIKE 'DATA_%';


-- Create the analyst role
CREATE ROLE data_analyst;

-- Put DATA_ENGINEER under SYSADMIN
GRANT ROLE data_engineer TO ROLE SYSADMIN;

-- Document the role hierarchy design
COMMENT ON ROLE data_engineer IS
'Inherited into SYSADMIN so administrative and deployment privileges are managed through the role hierarchy rather than granted directly to an individual user.';

SHOW GRANTS OF ROLE data_engineer;

SHOW ROLES LIKE 'DATA_%';

GRANT USAGE ON DATABASE retail_lakehouse TO ROLE data_engineer;
GRANT USAGE ON WAREHOUSE learn_wh TO ROLE data_engineer;

GRANT USAGE ON DATABASE retail_lakehouse TO ROLE data_analyst;
GRANT USAGE ON WAREHOUSE learn_wh TO ROLE data_analyst;

SHOW GRANTS TO ROLE data_engineer;

SHOW GRANTS TO ROLE data_analyst;

GRANT ROLE data_engineer TO USER SHASHANKMISHRA08;
GRANT ROLE data_analyst TO USER SHASHANKMISHRA08;

SHOW GRANTS TO USER SHASHANKMISHRA08;
USE ROLE data_engineer;
SELECT CURRENT_ROLE();
USE ROLE data_analyst;

SELECT CURRENT_ROLE();

USE ROLE ACCOUNTADMIN;
-- Future bronze tables will automatically be readable by analysts
GRANT SELECT ON FUTURE TABLES IN SCHEMA retail_lakehouse.bronze
TO ROLE data_analyst;
SHOW FUTURE GRANTS TO ROLE data_analyst;