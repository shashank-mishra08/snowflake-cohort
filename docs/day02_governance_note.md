# Day 2 — Snowflake Governance Note

## What is a Snowflake Tag?

A Snowflake tag is a schema-level object used to classify and organize data using metadata.

For example, a tag named `PII` can be used to identify columns that contain personally identifiable information, such as:

- Email addresses
- Phone numbers
- Customer names

Tags help separate **what the data represents** from **how security policies are applied**.

## Tag-Based Masking

Snowflake supports tag-based masking, where a masking policy can be associated with a tag instead of being manually attached to individual columns.

For example, a `PII` tag can identify sensitive columns across databases and schemas. A masking policy associated with that tag can then protect columns carrying the tag.

This means that instead of manually applying a masking policy to every sensitive column, the organization can manage protection through the data classification.

### Example

Without tag-based masking:

```text
CUSTOMERS.EMAIL       → Masking Policy
CUSTOMERS.PHONE       → Masking Policy
ORDERS.EMAIL          → Masking Policy
USERS.EMAIL           → Masking Policy