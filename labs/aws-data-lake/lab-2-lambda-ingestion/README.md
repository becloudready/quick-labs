# Lab 2 — Event-driven Ingestion (S3 → SQS → Lambda, S3 → Lambda direct, Lambda-as-ETL)

Curriculum anchor: **Day 1 — Module 4: Data Ingestion Use Cases.** Builds on the same per-student sandbox provisioned by Lab 1 — no new IAM users, no new buckets. Adds the Lambda execution role and gives students permissions to create their own functions, queues, S3 event notifications, Glue partitions, and Redshift Data API calls.

| File | Purpose |
|---|---|
| [`student-lambda-lab.md`](student-lambda-lab.md) | Student-facing walkthrough — three use cases, smoke tests, DLQ wiring, design considerations, knowledge check. |
| [`image_metadata_handler.py`](image_metadata_handler.py) | Reference Lambda — SQS-triggered, extracts metadata from S3 image uploads. Use case 1 (field imagery). |
| [`batch_file_handler.py`](batch_file_handler.py) | Reference Lambda — S3 ObjectCreated-triggered, copies batch drops to curated. Use case 2 (batch file pipeline). |
| [`csv_to_parquet_curated.py`](csv_to_parquet_curated.py) | Reference Lambda — Lambda-as-ETL for Redshift + S3 lakehouse orgs that can't use Glue ETL. Validates → Parquet → partitions → Glue catalog register → Redshift COPY. Use case 3. |
| [`student-user-policy.json`](student-user-policy.json) | **Lab-2 incremental student policy.** Attached as `quicklabs-<u>-lambda-ingestion`, in addition to (not replacing) Lab 1's policy. Adds SQS + Lambda + Lambda log groups + `iam:PassRole` for the Lambda execution role + Glue partition CRUD + Redshift Data API for student verification. |
| [`lambda-role-trust-policy.json`](lambda-role-trust-policy.json) | Per-student Lambda execution role trust policy (service-only). |
| [`lambda-role-inline-policy.json`](lambda-role-inline-policy.json) | Per-student Lambda role inline policy — S3 r/w + SQS consume + Glue catalog write (CreatePartition) + Redshift Data API (ExecuteStatement) for the Lambda-as-ETL pattern. |

No `terraform-lab/lab-2-lambda-ingestion/` module — the lab is student-driven (they create their own queues / functions / triggers as the exercise). The only pre-provisioned infrastructure is the Lambda execution role in `terraform-iam/`.

**Depends on:**
- `terraform-iam/` already applied (creates the Lambda execution role with Glue + Redshift Data perms + grants the same in the per-student `quicklabs-<u>-lambda-ingestion` policy)
- `terraform-lab/lab-1-data-lake/` already applied for this student (raw + curated buckets must exist)

**Optional for Use Case 3:**
- One cohort-shared Redshift Serverless workgroup + a copy-role the instructor provisions out-of-band. Without it, the function runs the S3-only path (Parquet + partition register) and skips COPY.
- AWS-managed "AWS SDK for pandas" Lambda Layer attached to the function — provides pandas + pyarrow.
