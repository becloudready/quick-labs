# Lab 3 — Data Governance: Lake Formation Deep Dive

Curriculum anchor: **Day 2 — Data Governance** (Modules 5–7).

## Folder layout

| Folder / File | Purpose |
|---|---|
| `slides/` | All deck content (instructor slides + Gemini image prompts) |
| `demo/` | Instructor-only demo runbooks, scripts, and data prep |
| `student/` | Student-facing lab, assignments, and quizzes |
| `lakeformation-user-policy.json` | **Terraform-referenced** — student-attached LF managed policy. Do not move. |
| `analyst-role-trust-policy.json` | **Terraform-referenced** — analyst role trust policy. Do not move. |
| `analyst-role-inline-policy.json` | **Terraform-referenced** — analyst role inline policy. Do not move. |

Lab Terraform: [`../terraform-lab/lab-3-lake-formation/`](../terraform-lab/lab-3-lake-formation/) — registers raw + curated S3 locations with LF, creates LF-Tags, sets up a row+column data cells filter, grants tag-scoped access to the analyst role.

## `slides/`

| File | What it covers |
|---|---|
| [`slides/lab-3-slides.md`](slides/lab-3-slides.md) | Full 6.5h day deck — Modules 5–7 with speaker notes, Well-Architected callouts, Gemini prompts |
| [`slides/lake-formation-intro-slides.md`](slides/lake-formation-intro-slides.md) | 8-slide intro pulled strictly from the AWS LF "What is Lake Formation?" doc page |
| [`slides/lf-grant-models-slides.md`](slides/lf-grant-models-slides.md) | 4 slides on Named Data Catalog resources vs LF-Tag-based grants |
| [`slides/lf-lessons-slides.md`](slides/lf-lessons-slides.md) | 4 slides distilling lessons from the live demo: why, how, "same query / three views," audit |

## `demo/`

| File / Folder | What it covers |
|---|---|
| [`demo/instructor-console-demo.md`](demo/instructor-console-demo.md) | **The main demo** — console-only walkthrough of LF access control (baseline → table grant → column → row+column → LF-Tags → CloudTrail) |
| [`demo/blueprint-rds-demo-runbook.md`](demo/blueprint-rds-demo-runbook.md) | Alternative ingestion demo — LF Blueprint pulling from RDS Postgres into S3 + catalog |
| [`demo/cdc-demo.md`](demo/cdc-demo.md) | Module 7 walkthrough — RDS PostgreSQL → AWS DMS (CDC) → S3/Redshift |
| [`demo/use-case-deep-dive.md`](demo/use-case-deep-dive.md) | Cross-account / federated catalog use cases |
| [`demo/personas/`](demo/personas/) | 3-persona "same query, three views" kit — IAM users, IAM policy, LF grant scripts |
| [`demo/rds-source/`](demo/rds-source/) | Postgres data prep utilities (oil data CSV + schema DDL + loader) — used by the blueprint demo and the student RDS lab |

## `student/`

| File | What it covers |
|---|---|
| [`student/student-lab-3-lake-formation.md`](student/student-lab-3-lake-formation.md) | Hands-on student lab: each student creates their own RDS Postgres, sets up a Glue JDBC connection, catalogs the table, runs 5 LF practice exercises with a partner |
| [`student/lab-3-assignments.md`](student/lab-3-assignments.md) | 3 take-home / in-class assignments wired to the terraform-managed lab |
| [`student/lab-3-quiz.md`](student/lab-3-quiz.md) | 10-question MCQ with answer key |
| [`student/day1-recap-quiz.docx`](student/day1-recap-quiz.docx) | 20-question Day 1 recap (MS Forms upload format) |

## Module map → time

| Module | Topic | Time | Lab touchpoint |
|---|---|---|---|
| 5 | Lake Formation Governance & Permissions | 3.5h | `terraform-lab/lab-3-lake-formation/` |
| 6 | Lake Formation Advanced — Athena Integration & Catalog | 2.0h | Same lab + Athena workgroup queries |
| 7 | CDC Management | 1.0h | [`demo/cdc-demo.md`](demo/cdc-demo.md) |

## Referenced AWS courses (free unless noted)

- **AWS Skill Builder — "Building Data Lakes on AWS"** — Modules 4 & 5 map almost 1-to-1 to today's content.
- **AWS Skill Builder — "Amazon Athena: Fundamentals"** (free, ~1h) — pre-read for Module 6.
- **AWS Workshop Studio — "Lake Formation Workshop"** — hands-on LF-Tag and cross-account labs, optional homework.
- **AWS Skill Builder — "AWS Database Migration Service: Getting Started"** (free, 30m) — pre-read for Module 7.
- **AWS Well-Architected — Data Analytics Lens** — sections on Data Catalog, Permissions, and Lineage.
- **AWS Whitepaper — "AWS Lake Formation: How it Works"** — keep handy for the architecture slide in Module 5.
