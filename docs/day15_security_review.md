# Day 15 — Trust Center / security posture

Account `PAYDEGL-YJ88482`, Enterprise trial. Trust Center UI: Snowsight →
**Admin → Trust Center**. This trial has a single human user; several
findings come from `SHOW USERS` / `SHOW ROLES` / `SHOW WAREHOUSES` because
the Trust Center scanner is edition/org-gated and did not return rows here.

## What is flagged (or would be)

| Finding | Evidence | Severity | Fix first? |
| --- | --- | --- | --- |
| User without MFA | `SHASHANKMISHRA08.has_mfa = false` | **High** | **Yes** — enable Snowflake MFA / Duo on the only login |
| Default role is ACCOUNTADMIN | `default_role = ACCOUNTADMIN` | **High** | **Yes** — `ALTER USER … SET DEFAULT_ROLE = DATA_ENGINEER` |
| ACCOUNTADMIN used for daily work | JWT CI + worksheets as ACCOUNTADMIN | High | Use `DATA_ENGINEER` for SQL; keep ACCOUNTADMIN for grants only |
| Password + key pair both enabled | `has_password=true`, `has_rsa_public_key=true` | Medium | Keep key pair for CI; require MFA on password logins |
| `COMPUTE_WH` has no resource monitor | `resource_monitor = null` | Medium | Attach `TRIAL_BUDGET` (Day 9 only covers `LEARN_WH`) |
| Network policy open | `allowed_interfaces = [ALL]` | Medium | Restrict to Snowsight + GitHub Actions IPs in prod |
| Query Acceleration on every WH | `enable_query_acceleration=true` | Low | Disable on X-Small lab WHs (cost, not a leak) |
| Unused built-in roles | USERADMIN / ORGADMIN assigned_to_users=0 | Info | Expected on a 1-user trial |

Positive: Day 2 created `DATA_ENGINEER` (under SYSADMIN) and `DATA_ANALYST`;
masking on email/phone; Cortex documented as running **as the caller role**;
agent `USAGE` granted to `DATA_ANALYST` not PUBLIC.

## First two fixes (order)

1. Turn on MFA for `SHASHANKMISHRA08` (Trust Center “users without MFA”).
2. Stop defaulting to ACCOUNTADMIN; analysts use `DATA_ANALYST` so Gold
   masking actually applies in CoWork / Streamlit.

## Trust Center UI steps (when the scanner is on)

1. Admin → Trust Center → open the default scanner / CIS Snowflake benchmark.
2. Filter **Failed** → export unused roles, MFA, network policy, ACCOUNTADMIN
   logins.
3. Track remediation weekly; do not grant `ACCOUNTADMIN` to the agent role.
