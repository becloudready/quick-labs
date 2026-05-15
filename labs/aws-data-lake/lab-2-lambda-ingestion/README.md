# Lab 2 — Event-driven Ingestion (S3 → SQS → Lambda, S3 → Lambda direct, Lambda-as-ETL)

Curriculum anchor: **Day 1 — Module 4: Data Ingestion Use Cases.** Builds on the same per-student sandbox provisioned by Lab 1 — no new IAM users, no new buckets. Adds the Lambda execution role and gives students permissions to create their own functions, queues, S3 event notifications, Glue partitions, and Redshift Data API calls.

## Folder layout

| Folder / File | Purpose |
|---|---|
| `slides/` | Architecture content for the deck |
| `student/` | Student-facing labs + reference Lambda code |
| `student-user-policy.json` | **Terraform-referenced** — Lab-2 incremental student policy. Do not move. |
| `lambda-role-trust-policy.json` | **Terraform-referenced** — Lambda execution role trust policy. Do not move. |
| `lambda-role-inline-policy.json` | **Terraform-referenced** — Lambda execution role inline policy. Do not move. |

## `slides/`

| File | What it covers |
|---|---|
| [`slides/architecture-diagram.md`](slides/architecture-diagram.md) | ASCII + Mermaid + Gemini prompt for the event-driven ingestion architecture (S3 landing zone, SQS fan-out, Lambda transform, S3 curated) |

## `student/`

| File | What it covers |
|---|---|
| [`student/student-lambda-lab.md`](student/student-lambda-lab.md) | Main student lab — three use cases (S3→SQS→Lambda image metadata, S3→Lambda batch direct, Lambda-as-ETL for Redshift + S3 lakehouse) with smoke tests, DLQ wiring, design considerations, knowledge check |
| [`student/student-lambda-redshift-lab.md`](student/student-lambda-redshift-lab.md) | Variant — Lambda-as-ETL deep dive ending in a Redshift COPY |
| [`student/lambda-code/`](student/lambda-code/) | Reference Lambda handler code students paste into the console |

### `student/lambda-code/`

| File | Use case |
|---|---|
| [`student/lambda-code/image_metadata_handler.py`](student/lambda-code/image_metadata_handler.py) | SQS-triggered, extracts metadata from S3 image uploads (use case 1 — field imagery) |
| [`student/lambda-code/batch_file_handler.py`](student/lambda-code/batch_file_handler.py) | S3 ObjectCreated-triggered, copies batch drops to curated (use case 2 — batch file pipeline) |
| [`student/lambda-code/csv_to_parquet_curated.py`](student/lambda-code/csv_to_parquet_curated.py) | Lambda-as-ETL for Redshift + S3 lakehouse orgs that can't use Glue ETL — validates → Parquet → partitions → Glue catalog register → Redshift COPY (use case 3) |

## Terraform integration

No `terraform-lab/lab-2-lambda-ingestion/` module — the lab is student-driven (students create their own queues / functions / triggers as the exercise). The only pre-provisioned infrastructure is the Lambda execution role in `terraform-iam/`.

**Depends on:**
- `terraform-iam/` already applied (creates the Lambda execution role with Glue + Redshift Data perms + grants the same in the per-student `quicklabs-<u>-lambda-ingestion` policy)
- `terraform-lab/lab-1-data-lake/` already applied for this student (raw + curated buckets must exist)

**Optional for Use Case 3:**
- One cohort-shared Redshift Serverless workgroup + a copy-role the instructor provisions out-of-band. Without it, the function runs the S3-only path (Parquet + partition register) and skips COPY.
- AWS-managed "AWS SDK for pandas" Lambda Layer attached to the function — provides pandas + pyarrow.
