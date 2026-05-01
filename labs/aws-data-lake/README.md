# AWS Data Lake Lab — copy-paste setup

One sandbox IAM user per student in your personal AWS account, region-locked to **us-west-2**, scoped to the `quicklabs-{username}` namespace. Students can build a small data lake (S3 → Glue Crawler → Glue Catalog → Glue ETL → Parquet → Athena) without touching anyone else's resources.

## Files in this folder

| File | What it is |
|---|---|
| `student-user-policy.json` | The big inline policy attached to each student's IAM user |
| `glue-role-trust-policy.json` | Trust policy for the per-student Glue service role |
| `glue-role-inline-policy.json` | Inline policy on the Glue role (S3 access + catalog scope) |
| `athena-workgroup-config.json` | Config for the per-student Athena workgroup |
| `oil_csv_to_parquet.py` | Sample Glue ETL job (Kaggle Crude Oil CSV → partitioned Parquet) |

## Placeholders to substitute

All JSONs use these placeholders. Replace before applying.

| Placeholder | Example | Notes |
|---|---|---|
| `{ACCOUNT_ID}` | `123456789012` | Your AWS account ID — run `aws sts get-caller-identity --query Account --output text` |
| `{USERNAME}` | `alice` | Student's username. Lowercase, alphanumeric + hyphens. |
| `{USERNAME_UNDERSCORED}` | `alice` (or `alice_johnson` if hyphenated) | Same as `{USERNAME}` but with hyphens replaced by underscores — Glue databases can't have hyphens |

## One-shot setup script (per student)

Set the variables at the top, paste the rest into a us-west-2 shell.

```bash
# --- Set per student ---
USERNAME=alice
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USERNAME_UNDERSCORED=$(echo "$USERNAME" | tr '-' '_')
RESULTS_BUCKET="quicklabs-${USERNAME}-athena-results"

export AWS_DEFAULT_REGION=us-west-2

# --- Render the policies (replaces {USERNAME}, {ACCOUNT_ID}, {USERNAME_UNDERSCORED}) ---
mkdir -p /tmp/quicklabs-$USERNAME
for f in student-user-policy.json glue-role-trust-policy.json \
         glue-role-inline-policy.json athena-workgroup-config.json; do
  sed -e "s/{ACCOUNT_ID}/${ACCOUNT_ID}/g" \
      -e "s/{USERNAME_UNDERSCORED}/${USERNAME_UNDERSCORED}/g" \
      -e "s/{USERNAME}/${USERNAME}/g" \
      "$f" > "/tmp/quicklabs-$USERNAME/$f"
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

Each failed expectation = one edit to `student-user-policy.json` (or `glue-role-inline-policy.json`) → re-render → re-apply with `aws iam put-user-policy` (or `put-role-policy`).

## Sample data + Glue script demo

The `oil_csv_to_parquet.py` script is a working PySpark Glue job that takes the Kaggle Crude Oil historical CSV and writes partitioned Parquet. Walkthrough:

```bash
# Upload sample data + script (as the student, after sign-in)
aws s3 mb s3://quicklabs-${USERNAME}-raw       --region us-west-2
aws s3 mb s3://quicklabs-${USERNAME}-curated   --region us-west-2
aws s3 mb s3://quicklabs-${USERNAME}-scripts   --region us-west-2

aws s3 cp ~/Downloads/Crude_Oil_historical_data.csv \
  s3://quicklabs-${USERNAME}-raw/oil/Crude_Oil_historical_data.csv
aws s3 cp oil_csv_to_parquet.py \
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

# Glue databases / crawlers / jobs the student created (manual — list and delete)
aws glue get-databases --query "DatabaseList[?starts_with(Name,'quicklabs_${USERNAME_UNDERSCORED}_')].Name" --output text
aws glue get-crawlers  --query "Crawlers[?starts_with(Name,'quicklabs-${USERNAME}-')].Name"      --output text
aws glue get-jobs      --query "Jobs[?starts_with(Name,'quicklabs-${USERNAME}-')].Name"          --output text
# then: aws glue delete-database / delete-crawler / delete-job for each
```

## Iteration

The whole lab is the policies + the script. When smoke-testing turns up gaps:

1. Edit `student-user-policy.json` or `glue-role-inline-policy.json`
2. Re-render with `sed` (the one-shot script handles this)
3. `aws iam put-user-policy` / `put-role-policy` to update
4. Re-test

No need to recreate the user — `put-*-policy` overwrites.
