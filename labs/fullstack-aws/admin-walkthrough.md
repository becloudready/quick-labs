# Admin walkthrough — Full-Stack on AWS

End-to-end the instructor runs once per cohort, before students arrive.

## Prereqs

- AWS CLI configured with admin creds for the cohort account (`aws sts get-caller-identity` works)
- Terraform ≥ 1.5 (`brew install terraform`)
- `gh` CLI authenticated as an org owner of `{ORG}` (`gh auth status`)
- The cohort's GitHub team exists (`gh api /orgs/{ORG}/teams/{TEAM_SLUG}` returns 200)
- A Copilot Business subscription on the org with seats available

## Step 0 — Roster

```bash
cd labs/fullstack-aws/terraform-iam
cp students.csv.example students.csv
$EDITOR students.csv   # username,full_name,email,github_username — one row per student
```

Symlink or copy the same CSV into `../github/` so both halves of the setup read one source of truth:

```bash
ln -sf ../terraform-iam/students.csv ../github/students.csv
```

## Step 1 — GitHub: team + Copilot

```bash
cd ../github

# 1a. Invite all students to the cohort team.
ORG=becloudready TEAM_SLUG=fullstack-cohort-01 ./add-team-members.sh students.csv

# 1b. Assign Copilot seats.
ORG=becloudready ./invite-copilot.sh students.csv
```

Both scripts are idempotent — re-run them to add late joiners.

> TODO: fill in error-handling, rate-limit pacing, and a `--dry-run` flag once the script shape is settled. The current stubs follow the pattern from `add-rohit-team.sh`.

## Step 2 — AWS: IAM users + sandbox policies

```bash
cd ../terraform-iam
terraform init
terraform plan
terraform apply
```

Outputs:

- `terraform output -json students` — sensitive map (scriptable)
- `students-credentials.csv` (chmod 0600, gitignored at the repo root) — `username, full_name, email, console_url, console_password, region`

What got created per student (`<u>` = the username from the CSV):

- IAM user `quicklabs-<u>` with console password (must change on first login)
- Sandbox policy `quicklabs-<u>-fullstack-sandbox` attached to the user

> TODO: extend `student-user-policy.json` with the service blocks your curriculum needs (Lambda, API Gateway, DynamoDB, CloudFront, etc.) before the first apply.

## Step 3 — Distribute credentials

```bash
while IFS=, read -r username full_name email console_url console_password region; do
  [[ "$username" == "username" ]] && continue
  cat <<EOF
to: $email
  GitHub:     accept the invite to {ORG}/{TEAM_SLUG} and the Copilot seat (check your email)
  AWS console: $console_url
  username:   $username
  password:   $console_password   (must change on first login)
  region:     $region (anything else is denied)

EOF
done < students-credentials.csv
```

## Step 4 — Smoke test (one student, incognito)

| Test | Expected |
|---|---|
| GitHub: sign in, see {ORG}/{TEAM_SLUG} repos | ✅ |
| GitHub: open VS Code, Copilot suggests inline | ✅ |
| AWS: sign in to console in `us-east-1` | ✅ |
| AWS: switch to `us-west-2`, open any service | mostly denied |
| AWS: create resource named `quicklabs-{u}-foo` (allowed service) | ✅ |
| AWS: create resource without the `quicklabs-{u}-` prefix | ❌ denied |
| AWS: try to create another IAM user | ❌ denied |

Each failed expectation → one edit to `student-user-policy.json` → `terraform apply` to re-render and re-attach.

## Cohort teardown

```bash
# 1. AWS
cd labs/fullstack-aws/terraform-iam
terraform destroy

# 2. GitHub — remove from team + revoke Copilot seats.
cd ../github
ORG=becloudready TEAM_SLUG=fullstack-cohort-01 ./remove-team-members.sh students.csv  # TODO: write
ORG=becloudready ./revoke-copilot.sh students.csv                                      # TODO: write
```
