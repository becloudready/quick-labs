# Full-Stack on AWS Lab

Per-student sandbox for a cohort learning full-stack development on AWS. Each student gets:

- **GitHub org membership** in `becloudready` (team-scoped repo access)
- **GitHub Copilot** seat assigned via the org
- **AWS console access** as an IAM user, region-locked to `us-east-1`, scoped to a `student-<slug>-*` namespace via principal-tag IAM policy

The AWS side uses Terraform; the GitHub side uses `gh` CLI scripts. The two are independent — this README focuses on the AWS side.

This lab pairs with the [vibe-code-to-prod bootcamp curriculum](https://github.com/becloudready/vibe-code-to-prod) — the policy is sized to cover every AWS service that bootcamp's chapters and projects touch.

## Files in this folder

| Path | What it is |
|---|---|
| [`terraform-iam/`](terraform-iam/) | Per-cohort IAM bootstrap. Reads `students.csv` and creates IAM users, group, managed policy, group memberships. |
| [`student-user-policy.json`](student-user-policy.json) | Core sandbox managed policy. Region lock, namespace scoping via `${aws:PrincipalTag/slug}`, IAM role + Lambda + S3 + DynamoDB + EC2 + CloudFront. |
| [`student-extras-policy.json`](student-extras-policy.json) | Second managed policy attached to the same group: Resource Groups Tagging API, IAM read, API Gateway console support paths, X-Ray, CloudWatch Logs Insights. Split out so each file stays under the 6144-char IAM managed-policy limit. |
| [`github/`](github/) | `gh` CLI scripts: add students to the org team, assign Copilot seats. (Independent of the AWS side.) |
| [`admin-walkthrough.md`](admin-walkthrough.md) | End-to-end onboarding the instructor runs before students arrive. |
| [`student-lab.md`](student-lab.md) | What the student sees on day 1 — sign-in flow. |

## Design

### One CSV = one cohort

The roster CSV has three columns:

```csv
username,full_name,cohort
alice-johnson@quicklabs.internal,Alice Johnson,fullstack-aws-batch-a
```

- **`username`** — IAM username, in email form. Two cohorts can have the same display name without colliding.
- **`full_name`** — written to a tag, used in the welcome-email CSV.
- **`cohort`** — drives the cohort group name, managed policy name, and per-user `cohort` tag. **All rows in a single CSV must share the same cohort value.**

### Slug derivation

The local-part of the email (everything before `@`) is the **slug** — used for IAM resource scoping. Why two identifiers:

| Identifier | Example | Where it appears | Why |
|---|---|---|---|
| `username` (email) | `alice-johnson@quicklabs.internal` | IAM user name | Stable, unique, email-shaped |
| `slug` | `alice-johnson` | Tag on the user; resolved inside the policy via `${aws:PrincipalTag/slug}` | S3/Lambda/DynamoDB resource names can't contain `@` or `.` |

The slug is also the value students pass as `var.student_name` when running the bootcamp's per-project Terraform — keeping resource naming and IAM scoping aligned.

### Group + managed policies, not per-user inline

For each cohort, Terraform creates:

- **Managed policy** `quicklabs-<cohort>-sandbox` — the core sandbox, scoped per-user via `${aws:PrincipalTag/slug}`
- **Managed policy** `quicklabs-<cohort>-extras` — bootcamp-specific extras (Resource Groups Tagging, X-Ray, Logs Insights, IAM read, API Gateway console support). Separate file because the combined JSON exceeds the IAM 6144-char managed-policy limit.
- **Group** `quicklabs-<cohort>-students` — both policies attached here
- **Group membership** per IAM user

Two managed policies per cohort instead of N inline policies per student. Easier to audit, version, and update mid-cohort. If you need to extend functionality, prefer adding to `student-extras-policy.json` — the core file is at ~99% of the size limit.

### Namespace: `student-<slug>-*`

Every resource a student creates must be named with the `student-<slug>-` prefix. The IAM policy enforces this for S3, Lambda, DynamoDB, CloudWatch Logs, and IAM roles.

This prefix matches the bootcamp's Terraform exactly — students supply `student_name=<slug>` as a Terraform variable and the bootcamp's modules name resources accordingly. The `tools/cleanup-student-resources.py` script in the bootcamp repo also keys on this prefix.

### What the policy allows

Region-locked to `us-east-1` (except IAM, STS, CloudFront, and S3 global list — all genuinely global). Within that region, in the student's namespace:

| Service | Scope |
|---|---|
| S3 | Full CRUD on `student-<slug>-*` buckets and objects |
| Lambda | Full CRUD on `student-<slug>-*` functions and layers |
| API Gateway v2 | Full CRUD in-region (ARN structure prevents name scoping) |
| DynamoDB | Full CRUD on `student-<slug>-*` tables |
| CloudWatch Logs | Full CRUD on `/aws/lambda/student-<slug>-*` and `/aws/apigateway/student-<slug>-*` |
| CloudWatch Metrics & Dashboards | Put/Get dashboards + alarms + custom metrics |
| EC2 | `RunInstances` limited to `t2.micro` / `t3.micro`; lifecycle + key pairs + security groups full |
| CloudFront | Full (global service; cannot be name-scoped) |
| IAM roles / instance profiles / policies | Full CRUD on `student-<slug>-*`; `PassRole` to lambda + ec2 + apigateway. `AttachRolePolicy` restricted to `AWSLambdaBasicExecutionRole`, `AWSLambdaVPCAccessExecutionRole`, and the student's own customer-managed policies — prevents `AdministratorAccess` escalation |
| IAM self-service | Change own password; create/list/delete own access keys for Terraform CLI use |
| Resource Groups Tagging API | Read + tag/untag — required by Lambda + S3 console tag UI |
| X-Ray | Read-only traces — for Lambda Monitor tab |
| CloudWatch Logs Insights | Run queries across log groups |

Hard-denied: user mutations (`iam:CreateUser`, `iam:AttachUserPolicy`, login profile changes for other users, group changes).

## Multi-cohort layout: Terraform workspaces

State is isolated per cohort via Terraform workspaces. One workspace per cohort, one CSV per cohort:

```bash
cd labs/fullstack-aws/terraform-iam

# Batch A
terraform workspace new batch-a
terraform apply                                          # uses students.csv

# Batch B (later)
terraform workspace new batch-b
terraform apply -var=roster_csv=students-batch-b.csv

# Switch between cohorts
terraform workspace select batch-a
terraform workspace select batch-b

# Destroy one cohort cleanly
terraform workspace select batch-a
terraform destroy
```

Both cohorts coexist in the same AWS account — separate groups, separate managed policies, separate user sets, independent destroys.

## Cohort lifecycle

| Phase | What happens | How |
|---|---|---|
| **Create** | 18 IAM users + login profiles + cohort group + managed policy + group memberships + `students-credentials-<cohort>.csv` for welcome emails | `terraform apply` in the cohort's workspace |
| **Run** | Students complete bootcamp labs — each creates Lambda/S3/DynamoDB/etc. under their `student-<slug>-*` namespace | Bootcamp curriculum drives this |
| **Tear down lab resources** | Delete what students created during labs (Lambda, S3, DynamoDB, EC2, log groups, IAM roles) | `python tools/cleanup-student-resources.py` looped over each slug, from the bootcamp repo |
| **Tear down cohort** | Delete IAM users, group, managed policy | `terraform destroy` in the cohort's workspace |

## Placeholders inside the policy file

| Placeholder | Where substituted | Notes |
|---|---|---|
| `{ACCOUNT_ID}` | At `terraform apply` time, by `main.tf` | Replaced with the live `aws_caller_identity` account ID |
| `${aws:PrincipalTag/slug}` | At IAM evaluation time, by AWS | Resolved per-request to the calling user's `slug` tag — preserved literally through Terraform |

## What the student can do

- Sign in to AWS Console in `us-east-1`
- Create / manage resources named `student-<slug>-*` across the lab's allowed services (S3, Lambda, API Gateway, DynamoDB, CloudWatch, EC2 micro instances, CloudFront, IAM roles in their namespace)
- Run the bootcamp's per-project Terraform with `student_name=<slug>`
- Create Lambda execution roles + EC2 instance profiles in their namespace; `PassRole` to lambda/ec2/apigateway

## What the student cannot do

- Touch any AWS region other than `us-east-1` (except global services)
- Touch resources outside the `student-<slug>-*` namespace
- Create or modify IAM users, access keys, or groups
- Launch EC2 instances larger than `t2.micro`/`t3.micro`
- Mutate roles or policies outside their namespace

## Known acceptable blast radius

CloudFront, API Gateway, and most EC2 mutating actions (beyond `RunInstances`) aren't tag-scoped — a student who discovers another student's resource ID could affect it. Acceptable for a trusted cohort; tighten with `aws:ResourceTag` conditions if you need hard cross-student isolation.
