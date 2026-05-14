# AWS Data Lake Lab 

One sandbox IAM user per student in your personal AWS account, region-locked to **us-west-2**, scoped to the `quicklabs-{username}` namespace. Students can build:

- a small data lake (S3 → Glue Crawler → Glue Catalog → Glue ETL → Parquet → Athena), and
- an event-driven ingestion pipeline on Lambda (S3 → SQS → Lambda, and S3 → Lambda direct — see [`lab-2-lambda-ingestion/student-lambda-lab.md`](lab-2-lambda-ingestion/student-lambda-lab.md)),

…without touching anyone else's resources.

## Files in this folder

| Path | What it is |
|---|---|
| [`terraform-iam/`](terraform-iam/) | Bulk-creates IAM users + Glue roles + Athena workgroups + sandbox policies from `students.csv`. Run this **first** for the cohort. |
| [`terraform-lab/`](terraform-lab/) | One Terraform module **per lab** (`lab-1-data-lake/`, `lab-3-lake-formation/`, …). Each pre-provisions that lab's resources per student via workspaces. Run **after** `terraform-iam`. |
| [`lab-1-data-lake/`](lab-1-data-lake/) | **Lab 1 — S3 / Glue / Athena data lake.** Cohort-wide `admin-walkthrough.md`, student walkthrough, ETL script, base sandbox policy, Glue + Athena role policies. The foundational lab; everything later builds on it. |
| [`lab-2-lambda-ingestion/`](lab-2-lambda-ingestion/) | **Lab 2 — Event-driven ingestion** (S3 → SQS → Lambda + S3 → Lambda direct). Student walkthrough, two sample handlers, Lambda execution-role policies. |
| [`lab-3-lake-formation/`](lab-3-lake-formation/) | **Lab 3 — Lake Formation governance** (row/column/tag-based access). Slide content, assignments, MCQ quiz, CDC demo walkthrough, LF + analyst-role policies. |
| `lab-1-data-lake/student-user-policy.json` | Lab-1 managed policy. Cross-cutting base (region-deny, console nav, IAM read/simulate, MFA) + Glue/Athena/S3 namespace permissions. Attached as `quicklabs-<u>-data-lake-sandbox`. |
| `lab-2-lambda-ingestion/student-user-policy.json` | Lab-2 **incremental** managed policy. SQS + Lambda + Lambda-role `iam:PassRole` + Lambda CloudWatch Logs. Attached as `quicklabs-<u>-lambda-ingestion`. Does not duplicate or replace Lab-1 — IAM Allows are union, so Lab 1 access stays intact. |
| `lab-1-data-lake/glue-role-trust-policy.json` | Trust policy for the per-student Glue service role |
| `lab-1-data-lake/glue-role-inline-policy.json` | Inline policy on the Glue role (S3 access + catalog scope) |
| `lab-1-data-lake/athena-workgroup-config.json` | Config for the per-student Athena workgroup (manual fallback only — Terraform inlines it) |
| `lab-1-data-lake/oil_csv_to_parquet.py` | Sample Glue ETL job (Kaggle Crude Oil CSV → partitioned Parquet) |
| `lab-1-data-lake/admin-walkthrough.md` | End-to-end pipeline walkthrough you run once under admin creds before handing the cohort their sandbox. |
| `lab-1-data-lake/student-lab.md` | The Lab-1 data-lake exercise students follow once they've got their console credentials |
| `lab-2-lambda-ingestion/lambda-role-trust-policy.json` | Trust policy for the per-student Lambda execution role |
| `lab-2-lambda-ingestion/lambda-role-inline-policy.json` | Inline policy on the Lambda role (S3 read/write to own buckets + SQS receive/delete on own queues) |
| `lab-2-lambda-ingestion/image_metadata_handler.py` | Sample Lambda — SQS-triggered, extracts metadata from S3 image uploads (use case 1) |
| `lab-2-lambda-ingestion/batch_file_handler.py` | Sample Lambda — S3-triggered, copies batch drops to the curated bucket (use case 2) |
| `lab-2-lambda-ingestion/student-lambda-lab.md` | The Lambda / event-driven ingestion exercise (depends on the same sandbox as Lab 1) |
| `lab-3-lake-formation/lakeformation-user-policy.json` | Second managed policy attached to each student. Lake Formation governance actions (grant, revoke, LF-Tags, data cells filters) + `sts:AssumeRole` on the analyst role. |
| `lab-3-lake-formation/analyst-role-trust-policy.json` / `lab-3-lake-formation/analyst-role-inline-policy.json` | Trust + inline policy for the per-student `quicklabs-<u>-data-analyst-role`. Used to demonstrate LF row/column/tag enforcement from a non-owner persona. |

## Placeholders to substitute

All JSONs use these placeholders. Replace before applying.

| Placeholder | Example | Notes |
|---|---|---|
| `{ACCOUNT_ID}` | `123456789012` | Your AWS account ID — run `aws sts get-caller-identity --query Account --output text` |
| `{USERNAME}` | `alice` | Student's username. Lowercase, alphanumeric + hyphens. |
| `{USERNAME_UNDERSCORED}` | `alice` (or `alice_johnson` if hyphenated) | Same as `{USERNAME}` but with hyphens replaced by underscores — Glue databases can't have hyphens |

## Bulk cohort setup with Terraform (recommended)

Two Terraform modules, applied in order. They are deliberately split so a failed apply on the data-pipeline side doesn't sit on top of the IAM state:

```
terraform-iam/                       ← one apply for the whole cohort (for_each over students.csv)
terraform-lab/
  lab-1-data-lake/                   ← one workspace + apply per student (state isolation)
  lab-3-lake-formation/              ← Lake Formation governance lab
  lab-4-redshift/                    ← Redshift / Spectrum lab (coming)
  lab-5-opensearch/                  ← OpenSearch lab (coming)
  lab-6-security-patterns/           ← Cross-service security lab (coming)
  lab-7-orchestration/               ← Step Functions + monitoring lab (coming)
  lab-8-monitoring/                  ← CloudWatch / CloudTrail / Cost ops lab (coming)
  lab-9-dynamodb/                    ← DynamoDB lab (coming)
  lab-10-documentdb/                 ← DocumentDB lab (coming)
```

### Prereqs

- AWS CLI configured with admin creds (`aws sts get-caller-identity` works)
- Terraform ≥ 1.5 (`brew install terraform`)
- Olist Crude Oil CSV downloaded locally — its path becomes `var.csv_local_path` for `terraform-lab/lab-1-data-lake/`. e.g. `~/Documents/bcr/training/Crude_Oil_historical_data.csv`

### Step 1 — provision IAM users from a CSV roster

```bash
cd labs/aws-data-lake/terraform-iam

# 1. Roster. Format: username,full_name,email  (only `username` is required;
#    full_name + email become AWS resource tags). Copy the template and edit:
cp students.csv.example students.csv
$EDITOR students.csv

# 2. One-time init.
terraform init

# 3. Plan, then apply.
terraform plan
terraform apply
```

Outputs land in two places:

- A sensitive map via `terraform output -json students` — useful in scripts
- `students-credentials.csv` (chmod 0600, gitignored at the repo root) — one row per student with everything you'd put in a welcome email: `username, full_name, email, console_url, console_password, region, athena_workgroup`

What got created per student (`<u>` = the username from the CSV):

- IAM user `quicklabs-<u>` with console password (must change on first login)
- Sandbox policy `quicklabs-<u>-data-lake-sandbox` attached to the user
- Glue service role `quicklabs-<u>-glue-role` (trust + S3/catalog scope)
- Lambda execution role `quicklabs-<u>-lambda-role` (S3 + SQS scope; for the Lambda lab)
- Athena workgroup `quicklabs-<u>-wg`
- S3 bucket `quicklabs-<u>-athena-results` (encrypted, private)

### Step 2 — provision each student's data pipeline

Each `terraform-lab/lab-N-*/` module takes a single `username` per apply, so we use **Terraform workspaces** to keep each student's state isolated. One workspace per student per lab, one state file per workspace.

```bash
CSV_PATH=~/Documents/bcr/training/Crude_Oil_historical_data.csv
ROSTER=../terraform-iam/students.csv

cd ../terraform-lab/lab-1-data-lake
terraform init   # one-time

# Loop the roster — skip header + blank lines, one workspace per student.
tail -n +2 "$ROSTER" | awk -F, 'NF >= 1 && $1 != ""' | while IFS=, read -r username _; do
  echo "── provisioning lab for $username ──"
  terraform workspace select "$username" 2>/dev/null \
    || terraform workspace new "$username"
  terraform apply -auto-approve \
    -var username="$username" \
    -var csv_local_path="$CSV_PATH"
done
```

What this creates per student (~2–3 min each, mostly the CSV upload):

- 3 S3 buckets: `quicklabs-<u>-{raw,curated,scripts}` (encrypted, private)
- Uploads `oil_csv_to_parquet.py` to the scripts bucket
- Uploads the Crude Oil CSV to `s3://quicklabs-<u>-raw/oil/`
- Glue catalog database `quicklabs_<u>_lake`
- 2 Glue crawlers (raw + curated)
- 1 Glue ETL job pointing at the IAM module's role

### Distribute credentials

`students-credentials.csv` from `terraform-iam` is a ready-to-email roster. One-liner to spit out one block per student:

```bash
cd ../terraform-iam
while IFS=, read -r username full_name email console_url console_password region wg; do
  [[ "$username" == "username" ]] && continue
  cat <<EOF
to: $email
  AWS console: $console_url
  username:    $username
  password:    $console_password   (must change on first login)
  region:      $region
  workgroup:   $wg

EOF
done < students-credentials.csv
```

### Inspecting / managing workspaces

```bash
cd ../terraform-lab/lab-1-data-lake
terraform workspace list                # all students + default
terraform workspace select alice        # switch context
terraform output                        # alice's bucket names, Glue DB, etc.
terraform state list                    # what's tracked for alice
```

### Adding or removing a student later

**IAM module** — edit the CSV, re-apply:

```bash
cd ../terraform-iam
$EDITOR students.csv          # add or remove rows
terraform apply               # creates new students or destroys dropped ones
```

`for_each` keys to `username`, so untouched rows stay untouched.

**Lab module** — for a new student, run the loop again (existing workspaces are skipped because their state shows nothing to do). To remove a student's Lab 1 (data lake) provisioning:

```bash
cd ../terraform-lab/lab-1-data-lake
terraform workspace select alice
terraform destroy -auto-approve -var username=alice -var csv_local_path=$CSV_PATH
terraform workspace select default
terraform workspace delete alice
```

### Cohort teardown

```bash
# 1. Destroy every student's Lab 1 (data lake) provisioning.
cd labs/aws-data-lake/terraform-lab/lab-1-data-lake
for ws in $(terraform workspace list | tr -d '*' | awk 'NF && $1 != "default"'); do
  terraform workspace select "$ws"
  terraform destroy -auto-approve -var username="$ws" -var csv_local_path="$CSV_PATH"
done
terraform workspace select default
for ws in $(terraform workspace list | tr -d '*' | awk 'NF && $1 != "default"'); do
  terraform workspace delete "$ws"
done

# 2. Destroy IAM users + per-student policies/roles/workgroups.
cd ../terraform-iam
terraform destroy
```

### Troubleshooting notes

- **Order matters.** Always `terraform-iam` first, `terraform-lab/lab-N-*` after. The Lab 1 module references the IAM module's Glue role ARN by string (`arn:aws:iam::ACCT:role/quicklabs-<u>-glue-role`) — if the role doesn't exist, Glue job creation fails with `EntityNotFoundException`. The same pattern holds for the Lambda role (Lab 2) and Lake Formation admin settings (Lab 3).
- **Stale state on the IAM side.** If a student's IAM user gets deleted out-of-band in AWS, the IAM module's next apply will fail trying to update tags on the missing user. Fix: `terraform apply -refresh-only` (drops the missing entries from state), then `terraform apply` recreates them.
- **One bad student doesn't break the cohort.** Per-student workspaces in each `terraform-lab/lab-N-*` module mean a failed apply for `bob` doesn't touch alice's state. Just re-run the loop after fixing the issue — completed students no-op.

---

## Manual single-student setup (fallback)

The bash one-shot below creates the same IAM resources as `terraform-iam` for **one** student. Use it when you don't have Terraform installed, or for a one-off student outside the cohort flow.

```bash
# --- Set per student ---
USERNAME=alice
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USERNAME_UNDERSCORED=$(echo "$USERNAME" | tr '-' '_')
RESULTS_BUCKET="quicklabs-${USERNAME}-athena-results"

export AWS_DEFAULT_REGION=us-west-2

# --- Render the policies (replaces {USERNAME}, {ACCOUNT_ID}, {USERNAME_UNDERSCORED}) ---
mkdir -p /tmp/quicklabs-$USERNAME
render() {  # $1 = source dir, $2 = file
  sed -e "s/{ACCOUNT_ID}/${ACCOUNT_ID}/g" \
      -e "s/{USERNAME_UNDERSCORED}/${USERNAME_UNDERSCORED}/g" \
      -e "s/{USERNAME}/${USERNAME}/g" \
      "$1/$2" > "/tmp/quicklabs-$USERNAME/$2"
}
for f in student-user-policy.json glue-role-trust-policy.json \
         glue-role-inline-policy.json athena-workgroup-config.json; do
  render lab-1-data-lake "$f"
done
for f in lambda-role-trust-policy.json lambda-role-inline-policy.json; do
  render lab-2-lambda-ingestion "$f"
done

# --- 1. Athena results bucket (workgroup needs this) ---
aws s3api create-bucket \
  --bucket "$RESULTS_BUCKET" \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-public-access-block --bucket "$RESULTS_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-encryption --bucket "$RESULTS_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# --- 2. Athena workgroup ---
aws athena create-work-group \
  --name "quicklabs-${USERNAME}-wg" \
  --configuration "file:///tmp/quicklabs-$USERNAME/athena-workgroup-config.json"

# --- 3. Glue service role (assumed by crawlers and jobs) ---
aws iam create-role \
  --role-name "quicklabs-${USERNAME}-glue-role" \
  --assume-role-policy-document "file:///tmp/quicklabs-$USERNAME/glue-role-trust-policy.json"
aws iam attach-role-policy \
  --role-name "quicklabs-${USERNAME}-glue-role" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
aws iam put-role-policy \
  --role-name "quicklabs-${USERNAME}-glue-role" \
  --policy-name "quicklabs-bucket-and-catalog-scope" \
  --policy-document "file:///tmp/quicklabs-$USERNAME/glue-role-inline-policy.json"

# --- 3b. Lambda execution role (assumed by Lambda functions in the Lambda lab) ---
aws iam create-role \
  --role-name "quicklabs-${USERNAME}-lambda-role" \
  --assume-role-policy-document "file:///tmp/quicklabs-$USERNAME/lambda-role-trust-policy.json"
aws iam attach-role-policy \
  --role-name "quicklabs-${USERNAME}-lambda-role" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
aws iam put-role-policy \
  --role-name "quicklabs-${USERNAME}-lambda-role" \
  --policy-name "quicklabs-bucket-and-queue-scope" \
  --policy-document "file:///tmp/quicklabs-$USERNAME/lambda-role-inline-policy.json"

# --- 4. Student IAM user + console password ---
aws iam create-user --user-name "quicklabs-${USERNAME}"
PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)Aa1!
aws iam create-login-profile \
  --user-name "quicklabs-${USERNAME}" \
  --password "$PASSWORD" \
  --password-reset-required
aws iam put-user-policy \
  --user-name "quicklabs-${USERNAME}" \
  --policy-name "quicklabs-data-lake-sandbox" \
  --policy-document "file:///tmp/quicklabs-$USERNAME/student-user-policy.json"

# --- 5. Hand to student ---
echo
echo "==== Hand these to student ${USERNAME} ===="
echo "Console URL : https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "Username    : quicklabs-${USERNAME}"
echo "Password    : ${PASSWORD}"
echo "Region      : us-west-2 (anything else is denied)"
echo "Workgroup   : quicklabs-${USERNAME}-wg"
echo "Glue role   : quicklabs-${USERNAME}-glue-role"
echo "Lambda role : quicklabs-${USERNAME}-lambda-role"
```

## What the student can do

In **us-west-2 only**:

- Sign in to the AWS console
- Create / delete / configure S3 buckets named `quicklabs-{username}-*`
- Read / write / list any objects in their own buckets
- Create Glue databases named `quicklabs_{username_underscored}_*` and tables under them
- Create Glue crawlers / jobs / triggers / connections named `quicklabs-{username}-*`
- Run Athena queries through their own workgroup (`quicklabs-{username}-wg`)
- Read CloudWatch Logs for crawler / job runs (`/aws-glue/*` log groups)
- Create SQS queues named `quicklabs-{username}-*` (and configure DLQs on them)
- Create Lambda functions named `quicklabs-{username}-*` and wire S3 / SQS triggers
- Pass the per-student Lambda role (`quicklabs-{username}-lambda-role`) to Lambda only
- Read Lambda CloudWatch Logs under `/aws/lambda/quicklabs-{username}-*`

## What the student cannot do

- Anything outside us-west-2
- Touch any S3 bucket not matching `quicklabs-{username}-*`
- Use any Athena workgroup other than their own
- Pass any IAM role other than their own Glue service role
- Create or modify IAM users / roles
- Write Glue tables or partitions outside their `quicklabs_{username}_*` database namespace (the Glue role is explicitly denied this)

## Smoke-test loop

Sign in as `quicklabs-{username}` in an incognito window and run:

| Test | Expected |
|---|---|
| Switch to us-east-1 → open S3 | mostly denied |
| Switch back to us-west-2 → create bucket `quicklabs-{username}-raw` | ✅ |
| Try to create bucket `mybucket-{username}` | ❌ denied (no `quicklabs-{username}-` prefix) |
| Upload CSV to `quicklabs-{username}-raw` | ✅ |
| List all buckets (S3 home) | sees names of all buckets, can only open own |
| Create Glue database `quicklabs_{username}_lake` | ✅ |
| Create crawler `quicklabs-{username}-raw-crawler` with `quicklabs-{username}-glue-role` | ✅ |
| Run the crawler | ✅; tables appear in `quicklabs_{username}_lake` |
| Switch Athena to workgroup `quicklabs-{username}-wg` and `SELECT * FROM ... LIMIT 10` | ✅ |
| Try to switch to Athena `primary` workgroup | ❌ denied |
| Try to create another IAM user | ❌ denied |

Each failed expectation = one edit to `lab-1-data-lake/student-user-policy.json` (or `lab-1-data-lake/glue-role-inline-policy.json`) → re-render → re-apply with `aws iam put-user-policy` (or `put-role-policy`).

## Sample data + Glue script demo

The `oil_csv_to_parquet.py` script is a working PySpark Glue job that takes the Kaggle Crude Oil historical CSV and writes partitioned Parquet. Walkthrough:

```bash
# Upload sample data + script (as the student, after sign-in)
aws s3 mb s3://quicklabs-${USERNAME}-raw       --region us-west-2
aws s3 mb s3://quicklabs-${USERNAME}-curated   --region us-west-2
aws s3 mb s3://quicklabs-${USERNAME}-scripts   --region us-west-2

aws s3 cp ~/Downloads/Crude_Oil_historical_data.csv \
  s3://quicklabs-${USERNAME}-raw/oil/Crude_Oil_historical_data.csv
aws s3 cp lab-1-data-lake/oil_csv_to_parquet.py \
  s3://quicklabs-${USERNAME}-scripts/oil_csv_to_parquet.py
```

Then in the Glue console (still as the student):

- Jobs → Create job → Spark, Python 3, Glue 4.0+
- Name: `quicklabs-${USERNAME}-oil-etl`
- IAM role: `quicklabs-${USERNAME}-glue-role`
- Script: `s3://quicklabs-${USERNAME}-scripts/oil_csv_to_parquet.py`
- Job parameters:
  ```
  --source_path = s3://quicklabs-{USERNAME}-raw/oil/Crude_Oil_historical_data.csv
  --target_path = s3://quicklabs-{USERNAME}-curated/oil/
  ```
- Worker type: G.1X, 2 workers
- Run

Output lands as Parquet partitioned by year. Either run a Glue crawler against the curated path or use the `CREATE EXTERNAL TABLE` DDL in the script's docstring to register it. Then query in Athena.

## Cleanup (per student)

```bash
USERNAME=alice
RESULTS_BUCKET="quicklabs-${USERNAME}-athena-results"

# Empty + delete all student buckets (matches the prefix)
for b in $(aws s3api list-buckets --query "Buckets[?starts_with(Name,'quicklabs-${USERNAME}-')].Name" --output text); do
  aws s3 rm "s3://$b" --recursive
  aws s3api delete-bucket --bucket "$b"
done

# Athena workgroup
aws athena delete-work-group --work-group "quicklabs-${USERNAME}-wg" --recursive-delete-option

# IAM user (delete login profile + inline policies first)
aws iam delete-login-profile --user-name "quicklabs-${USERNAME}" || true
aws iam delete-user-policy   --user-name "quicklabs-${USERNAME}" --policy-name "quicklabs-data-lake-sandbox" || true
aws iam delete-user          --user-name "quicklabs-${USERNAME}"

# Glue role
aws iam delete-role-policy   --role-name "quicklabs-${USERNAME}-glue-role" --policy-name "quicklabs-bucket-and-catalog-scope" || true
aws iam detach-role-policy   --role-name "quicklabs-${USERNAME}-glue-role" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole" || true
aws iam delete-role          --role-name "quicklabs-${USERNAME}-glue-role"

# Lambda role
aws iam delete-role-policy   --role-name "quicklabs-${USERNAME}-lambda-role" --policy-name "quicklabs-bucket-and-queue-scope" || true
aws iam detach-role-policy   --role-name "quicklabs-${USERNAME}-lambda-role" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" || true
aws iam delete-role          --role-name "quicklabs-${USERNAME}-lambda-role"

# Lambda functions, SQS queues, and event source mappings the student created
# (manual — list, detach triggers, then delete)
aws lambda list-functions --query "Functions[?starts_with(FunctionName,'quicklabs-${USERNAME}-')].FunctionName" --output text
aws sqs list-queues --queue-name-prefix "quicklabs-${USERNAME}-" --query "QueueUrls" --output text
# then: aws lambda delete-event-source-mapping / aws lambda delete-function / aws sqs delete-queue for each

# Glue databases / crawlers / jobs the student created (manual — list and delete)
aws glue get-databases --query "DatabaseList[?starts_with(Name,'quicklabs_${USERNAME_UNDERSCORED}_')].Name" --output text
aws glue get-crawlers  --query "Crawlers[?starts_with(Name,'quicklabs-${USERNAME}-')].Name"      --output text
aws glue get-jobs      --query "Jobs[?starts_with(Name,'quicklabs-${USERNAME}-')].Name"          --output text
# then: aws glue delete-database / delete-crawler / delete-job for each
```

## Iteration

The whole lab is the policies + the script. When smoke-testing turns up gaps:

1. Edit `lab-1-data-lake/student-user-policy.json` or `lab-1-data-lake/glue-role-inline-policy.json`
2. Re-render with `sed` (the one-shot script handles this)
3. `aws iam put-user-policy` / `put-role-policy` to update
4. Re-test

No need to recreate the user — `put-*-policy` overwrites.
