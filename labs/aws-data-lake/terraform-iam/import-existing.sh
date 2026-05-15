#!/usr/bin/env bash
#
# import-existing.sh — bootstrap script for terraform-iam idempotence
#
# When the AWS account already has IAM users / roles / policies / S3 buckets
# / Athena workgroups from a prior apply that didn't save state, `terraform
# apply` blows up with `EntityAlreadyExists` / `BucketAlreadyOwnedByYou`.
#
# This script reads `students.csv` and for each student checks AWS for every
# resource terraform-iam manages. If a resource exists in AWS but is not in
# Terraform state, it runs `terraform import` to reconcile. After it
# finishes, `terraform apply` should be a clean diff (no-op for matched
# resources, create-only for anything new like `student_lab2` policies).
#
# Safe to re-run — already-in-state resources and missing-in-AWS resources
# are skipped.
#
# Usage:
#   cd terraform-iam
#   ./import-existing.sh [students.csv]
#
# Requirements:
#   - terraform initialised (`terraform init` already ran in this dir)
#   - AWS CLI authenticated as the same identity terraform-iam uses
#   - jq

set -euo pipefail

ROSTER="${1:-students.csv}"
[[ -f "$ROSTER" ]] || { echo "Roster not found: $ROSTER" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE=$(terraform state list 2>/dev/null || true)

in_state() {
  grep -qFx -- "$1" <<< "$STATE"
}

# maybe_import <tf_addr> <import_id> <check_cmd>
#   check_cmd: a shell expression that exits 0 if the resource exists in AWS.
maybe_import() {
  local tf_addr="$1" import_id="$2" check_cmd="$3"

  if in_state "$tf_addr"; then
    echo "    [skip] in state:    $tf_addr"
    return 0
  fi

  if ! bash -c "$check_cmd" >/dev/null 2>&1; then
    echo "    [skip] not in AWS:  $tf_addr"
    return 0
  fi

  echo "    [imp ] $tf_addr  <-  $import_id"
  if terraform import -input=false "$tf_addr" "$import_id" >/tmp/tf-import.log 2>&1; then
    STATE=$(terraform state list 2>/dev/null || true)
  else
    echo "    [FAIL] import failed for $tf_addr. Last 10 lines of output:" >&2
    tail -n 10 /tmp/tf-import.log >&2
    return 1
  fi
}

# Account-wide singleton — do this first so subsequent failures don't strand it.
echo "== account-wide =="
maybe_import \
  "aws_lakeformation_data_lake_settings.cohort" \
  "$ACCOUNT_ID" \
  "aws lakeformation get-data-lake-settings --catalog-id $ACCOUNT_ID"

# Per-student loop. Skip the CSV header.
tail -n +2 "$ROSTER" | awk -F, 'NF >= 1 && $1 != "" && $1 !~ /^#/' | \
while IFS=, read -r u _rest; do
  echo "== $u =="

  user="quicklabs-$u"
  glue_role="quicklabs-$u-glue-role"
  lambda_role="quicklabs-$u-lambda-role"
  analyst_role="quicklabs-$u-data-analyst-role"
  wg="quicklabs-$u-wg"
  athena_bucket="quicklabs-$u-athena-results"
  sandbox_arn="arn:aws:iam::${ACCOUNT_ID}:policy/quicklabs-$u-data-lake-sandbox"
  lab2_arn="arn:aws:iam::${ACCOUNT_ID}:policy/quicklabs-$u-lambda-ingestion"
  lf_arn="arn:aws:iam::${ACCOUNT_ID}:policy/quicklabs-$u-lakeformation"
  glue_managed_arn="arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  lambda_basic_arn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

  # --- IAM users + login profile ---
  maybe_import "aws_iam_user.student[\"$u\"]" \
    "$user" \
    "aws iam get-user --user-name $user"

  maybe_import "aws_iam_user_login_profile.student[\"$u\"]" \
    "$user" \
    "aws iam get-login-profile --user-name $user"

  # --- IAM managed policies (per-student) ---
  maybe_import "aws_iam_policy.student[\"$u\"]" \
    "$sandbox_arn" \
    "aws iam get-policy --policy-arn $sandbox_arn"

  maybe_import "aws_iam_policy.student_lab2[\"$u\"]" \
    "$lab2_arn" \
    "aws iam get-policy --policy-arn $lab2_arn"

  maybe_import "aws_iam_policy.student_lakeformation[\"$u\"]" \
    "$lf_arn" \
    "aws iam get-policy --policy-arn $lf_arn"

  # --- User → policy attachments (id = user/policy-arn) ---
  attached_to_user() {
    local user="$1" arn="$2"
    aws iam list-attached-user-policies --user-name "$user" \
      --query "AttachedPolicies[?PolicyArn=='$arn'] | length(@)" \
      --output text 2>/dev/null | grep -q '^[1-9]'
  }

  maybe_import "aws_iam_user_policy_attachment.student[\"$u\"]" \
    "$user/$sandbox_arn" \
    "attached_to_user $user $sandbox_arn"
  maybe_import "aws_iam_user_policy_attachment.student_lab2[\"$u\"]" \
    "$user/$lab2_arn" \
    "attached_to_user $user $lab2_arn"
  maybe_import "aws_iam_user_policy_attachment.student_lakeformation[\"$u\"]" \
    "$user/$lf_arn" \
    "attached_to_user $user $lf_arn"

  # --- Glue service role + its attachments + inline policy ---
  maybe_import "aws_iam_role.glue[\"$u\"]" \
    "$glue_role" \
    "aws iam get-role --role-name $glue_role"

  attached_to_role() {
    local role="$1" arn="$2"
    aws iam list-attached-role-policies --role-name "$role" \
      --query "AttachedPolicies[?PolicyArn=='$arn'] | length(@)" \
      --output text 2>/dev/null | grep -q '^[1-9]'
  }

  maybe_import "aws_iam_role_policy_attachment.glue_managed[\"$u\"]" \
    "$glue_role/$glue_managed_arn" \
    "attached_to_role $glue_role $glue_managed_arn"

  maybe_import "aws_iam_role_policy.glue_inline[\"$u\"]" \
    "$glue_role:quicklabs-bucket-and-catalog-scope" \
    "aws iam get-role-policy --role-name $glue_role --policy-name quicklabs-bucket-and-catalog-scope"

  # --- Lambda execution role + attachments + inline policy ---
  maybe_import "aws_iam_role.lambda[\"$u\"]" \
    "$lambda_role" \
    "aws iam get-role --role-name $lambda_role"

  maybe_import "aws_iam_role_policy_attachment.lambda_basic[\"$u\"]" \
    "$lambda_role/$lambda_basic_arn" \
    "attached_to_role $lambda_role $lambda_basic_arn"

  maybe_import "aws_iam_role_policy.lambda_inline[\"$u\"]" \
    "$lambda_role:quicklabs-bucket-and-queue-scope" \
    "aws iam get-role-policy --role-name $lambda_role --policy-name quicklabs-bucket-and-queue-scope"

  # --- Data analyst role + inline policy ---
  maybe_import "aws_iam_role.analyst[\"$u\"]" \
    "$analyst_role" \
    "aws iam get-role --role-name $analyst_role"

  maybe_import "aws_iam_role_policy.analyst_inline[\"$u\"]" \
    "$analyst_role:quicklabs-analyst-athena-and-catalog-read" \
    "aws iam get-role-policy --role-name $analyst_role --policy-name quicklabs-analyst-athena-and-catalog-read"

  # --- Athena results bucket + its sub-configs ---
  maybe_import "aws_s3_bucket.athena_results[\"$u\"]" \
    "$athena_bucket" \
    "aws s3api head-bucket --bucket $athena_bucket"

  maybe_import "aws_s3_bucket_public_access_block.athena_results[\"$u\"]" \
    "$athena_bucket" \
    "aws s3api get-public-access-block --bucket $athena_bucket"

  maybe_import "aws_s3_bucket_server_side_encryption_configuration.athena_results[\"$u\"]" \
    "$athena_bucket" \
    "aws s3api get-bucket-encryption --bucket $athena_bucket"

  # --- Athena workgroup ---
  maybe_import "aws_athena_workgroup.student[\"$u\"]" \
    "$wg" \
    "aws athena get-work-group --work-group $wg"

done

echo ""
echo "Done. Re-run \`terraform plan\` — drift should now be either:"
echo "  - empty (everything in sync), or"
echo "  - 'will create' for resources missing in AWS (e.g. new student_lab2 policy)."
echo "Then \`terraform apply\` to create the remainder."
