# Lab 1 — S3 / Glue / Athena Data Lake

Curriculum anchor: **Day 1 — AWS Foundations & Data Storage Architecture** (Modules 1–3). The foundational lab; every later lab assumes the per-student namespace and Glue catalog this one creates.

| File | Purpose |
|---|---|
| [`student-lab.md`](student-lab.md) | Student-facing walkthrough — sign in, run the Glue ETL, query Athena. |
| [`admin-walkthrough.md`](admin-walkthrough.md) | Instructor end-to-end run-through under admin creds before students sign in. **Cohort-wide setup** — applies to all labs that follow, not just Lab 1. |
| [`oil_csv_to_parquet.py`](oil_csv_to_parquet.py) | The Glue ETL script — Kaggle Crude Oil CSV → partitioned Parquet. Uploaded to `s3://quicklabs-<u>-scripts/` by `terraform-lab/lab-1-data-lake/`. |
| [`student-user-policy.json`](student-user-policy.json) | Per-student sandbox IAM policy attached as `quicklabs-<u>-data-lake-sandbox`. Cross-cutting base (region-deny, console nav, IAM read/simulate, MFA) + Glue/Athena/S3 namespace. **Lab-1-only**; Lab 2's incremental SQS/Lambda permissions live in `lab-2-lambda-ingestion/student-user-policy.json` and are attached as a separate managed policy. |
| [`glue-role-trust-policy.json`](glue-role-trust-policy.json) / [`glue-role-inline-policy.json`](glue-role-inline-policy.json) | Per-student Glue service role (trust + inline). |
| [`athena-workgroup-config.json`](athena-workgroup-config.json) | Workgroup config used by the manual single-student fallback in the parent README. Terraform inlines the same config. |

Lab Terraform: [`../terraform-lab/lab-1-data-lake/`](../terraform-lab/lab-1-data-lake/) — pre-provisions raw / curated / scripts buckets, Glue DB, crawlers, ETL job per student.
