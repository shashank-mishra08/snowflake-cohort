# Day 8 — CI/CD, Git Integration & Schema Change Management

## Overview

Day 8 moves Snowflake deployment from manual Snowsight execution to
version-controlled migrations deployed through Snowflake CLI and GitHub Actions.

## Git Integration

Created a Snowflake Git repository object:

- Repository: `RETAIL_LAKEHOUSE.DBT.SNOWFLAKE_COHORT_GIT`
- GitHub repository: `shashank-mishra08/snowflake-cohort`
- API integration: `DAY08_GITHUB_API`

Verified the repository contents using:

```sql
LIST @RETAIL_LAKEHOUSE.DBT.SNOWFLAKE_COHORT_GIT/branches/main;
