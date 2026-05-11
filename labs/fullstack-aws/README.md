# Full-Stack on AWS Lab — copy-paste setup

Per-student sandbox for a cohort learning full-stack development on AWS. Each student gets:

- **GitHub org membership** in `becloudready` (team-scoped repo access)
- **GitHub Copilot** seat assigned via the org
- **AWS console access** as a region-locked IAM user (`us-east-1`), scoped to the `quicklabs-{username}` namespace and a curated set of full-stack services (e.g. S3, Lambda, API Gateway, CloudFront, DynamoDB, CloudWatch Logs — exact list TBD in [`student-user-policy.json`](student-user-policy.json))

The AWS side uses Terraform; the GitHub side uses `gh` CLI scripts.

## Files in this folder

| Path | What it is |
|---|---|
| [`terraform-iam/`](terraform-iam/) | Bulk-creates IAM users + sandbox policies from `students.csv`. Run this once per cohort. |
| [`github/`](github/) | `gh` CLI scripts: add students to the org team, assign Copilot seats. |
| `student-user-policy.json` | Inline IAM policy attached to each student's user — region lock + namespace scope. (Skeleton; fill in the service blocks for your curriculum.) |
| `admin-walkthrough.md` | End-to-end onboarding the instructor runs before students arrive. |
| `student-lab.md` | What the student sees on day 1 — GitHub login, Copilot setup, AWS console sign-in. |

## Placeholders to substitute

| Placeholder | Example | Notes |
|---|---|---|
| `{ACCOUNT_ID}` | `123456789012` | Your AWS account ID — `aws sts get-caller-identity --query Account --output text` |
| `{USERNAME}` | `alice` | Student's username. Lowercase, alphanumeric + hyphens. Same string for AWS IAM and GitHub team membership. |
| `{ORG}` | `becloudready` | GitHub org. |
| `{TEAM_SLUG}` | `fullstack-cohort-01` | GitHub team slug the cohort joins. |

## Roster

One CSV is the source of truth for both the AWS and GitHub setup:

```
username,full_name,email,github_username
alice,Alice Johnson,alice@quicklabs.internal,alice-gh
```

- `username` → AWS IAM user `quicklabs-<username>`
- `github_username` → invited to the GitHub org team + given a Copilot seat
- `full_name` + `email` → tags on the IAM user; also used for the welcome email

Copy `terraform-iam/students.csv.example` to `students.csv` and edit.

## Order of operations

1. **GitHub** — run [`github/add-team-members.sh`](github/add-team-members.sh) to invite students to the org team, then [`github/invite-copilot.sh`](github/invite-copilot.sh) to assign Copilot seats.
2. **AWS** — `cd terraform-iam && terraform apply` to create the IAM users + policies. Outputs `students-credentials.csv` (gitignored, 0600) with console URL + temporary password per student.
3. **Distribute** — one welcome email per student with their GitHub invite link, Copilot activation note, and AWS console creds.

Full end-to-end is in [`admin-walkthrough.md`](admin-walkthrough.md).

## What the student can do

- Sign in to the GitHub org, accept Copilot seat, clone cohort repos
- Sign in to the AWS console in `us-east-1` only
- Create / manage resources named `quicklabs-{username}-*` across the lab's allowed services
- (Service list is intentionally a TODO in `student-user-policy.json` — fill it in for your curriculum)

## What the student cannot do

- Touch any AWS region other than `us-east-1`
- Touch resources outside the `quicklabs-{username}-*` namespace
- Create or modify IAM users / roles
- Access GitHub repos outside the cohort team

---

## Status

🚧 **Scaffold.** The structure mirrors [`labs/aws-data-lake/`](../aws-data-lake/). The `terraform-iam/` module, `student-user-policy.json`, and `github/` scripts are stubs — wire them up to your curriculum before running on a real cohort.
