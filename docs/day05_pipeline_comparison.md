# Day 5 — Streams + Tasks vs Dynamic Tables

## Overview

Day 5 demonstrates two approaches for automatically transforming data from Bronze into Silver and Gold.

### Approach 1 — Streams + Tasks

```text
Bronze
  ↓
Stream
  ↓
Task
  ↓
Silver
  ↓
Task
  ↓
Gold