provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "Quicklabs"
      Lab     = "aws-data-lake"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Parse students.csv. Required column: username. Optional: full_name, email.
  # username must be lowercase, alphanumeric + hyphens (used in resource names).
  students_list = csvdecode(file(var.students_csv))
  students      = { for s in local.students_list : s.username => s }
  account_id    = data.aws_caller_identity.current.account_id
  policies_dir  = "${path.module}/.."

  # The JSON files use {USERNAME}, {USERNAME_UNDERSCORED}, {ACCOUNT_ID} placeholders
  # so the same files work for both the bash setup and Terraform. We use replace()
  # rather than templatefile() because the policies contain ${aws:RequestedRegion}
  # IAM policy variables that would conflict with TF interpolation.
  # Minified via jsonencode(jsondecode(...)) — the user policy is ~6KB pretty-
  # printed, ~4.3KB minified. Inline user policies are capped at 2048 bytes;
  # managed policies at 6144. We use managed for headroom and minify anyway.
  rendered_user_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/lab-1-data-lake/student-user-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Trust policy needs per-student rendering because it grants the student's
  # IAM user the right to assume the role (required for Glue Interactive
  # Sessions / notebooks — without it, CreateSession returns
  # "Cross-account pass role is not allowed" even within the same account).
  rendered_glue_trust_policy = {
    for u, s in local.students : u => replace(replace(
      file("${local.policies_dir}/lab-1-data-lake/glue-role-trust-policy.json"),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)
  }

  rendered_glue_inline_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/lab-1-data-lake/glue-role-inline-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Lambda execution role — assumed by every Lambda function the student creates
  # (the Lambda-lab use cases: S3 → SQS → Lambda, and S3 → Lambda direct).
  # Trust policy is service-only (no student-assume) — Lambda is invoked async
  # by S3/SQS, students never assume the role themselves.
  rendered_lambda_trust_policy = file("${local.policies_dir}/lab-2-lambda-ingestion/lambda-role-trust-policy.json")

  rendered_lambda_inline_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/lab-2-lambda-ingestion/lambda-role-inline-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Lab 2 student policy — incremental over the Lab 1 sandbox. Adds SQS, Lambda
  # function/event-source-mapping actions, PassRole for the Lambda role, and
  # Lambda CloudWatch Logs access. Attached alongside (not replacing) Lab 1.
  # Also: Glue partition CRUD + Redshift Data API for Use Case 3 (Lambda-as-ETL).
  rendered_lab2_user_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/lab-2-lambda-ingestion/student-user-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Lake Formation policy attached to the student (Lab 3). Incremental over
  # Lab 1 + Lab 2 — adds LF grant/revoke/tag/filter actions + sts:AssumeRole
  # on the analyst role.
  rendered_lf_user_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(
      file("${local.policies_dir}/lab-3-lake-formation/lakeformation-user-policy.json"),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Per-student "data analyst" role — the student grants LF permissions to this
  # role in the Day 2 lab, then assumes it via `sts assume-role` to query as
  # the analyst persona.
  rendered_analyst_trust_policy = {
    for u, s in local.students : u => replace(replace(
      file("${local.policies_dir}/lab-3-lake-formation/analyst-role-trust-policy.json"),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)
  }

  rendered_analyst_inline_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/lab-3-lake-formation/analyst-role-inline-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  # Per-student tags applied to each AWS resource so cost reports + IAM listings
  # carry the student identity. FullName / Email only included if present in CSV.
  student_tags = { for u, s in local.students : u => merge(
    { Student = u },
    try(s.full_name, "") != "" ? { FullName = s.full_name } : {},
    try(s.email, "") != "" ? { Email = s.email } : {},
  ) }
}

# --- Glue service role (assumed by crawlers and jobs run by the student) ---

resource "aws_iam_role" "glue" {
  for_each           = local.students
  name               = "quicklabs-${each.key}-glue-role"
  assume_role_policy = local.rendered_glue_trust_policy[each.key]
  tags               = local.student_tags[each.key]
}

resource "aws_iam_role_policy_attachment" "glue_managed" {
  for_each   = local.students
  role       = aws_iam_role.glue[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_inline" {
  for_each = local.students
  name     = "quicklabs-bucket-and-catalog-scope"
  role     = aws_iam_role.glue[each.key].id
  policy   = local.rendered_glue_inline_policy[each.key]
}

# --- Lambda execution role (assumed by every Lambda function the student
#     creates — handlers for the S3 → SQS → Lambda and S3 → Lambda direct
#     ingestion patterns from the Lambda lab) ---

resource "aws_iam_role" "lambda" {
  for_each           = local.students
  name               = "quicklabs-${each.key}-lambda-role"
  assume_role_policy = local.rendered_lambda_trust_policy
  tags               = local.student_tags[each.key]
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each   = local.students
  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_inline" {
  for_each = local.students
  name     = "quicklabs-bucket-and-queue-scope"
  role     = aws_iam_role.lambda[each.key].id
  policy   = local.rendered_lambda_inline_policy[each.key]
}

# --- Athena results bucket (workgroup writes query output here) ---

resource "aws_s3_bucket" "athena_results" {
  for_each      = local.students
  bucket        = "quicklabs-${each.key}-athena-results"
  force_destroy = true
  tags          = local.student_tags[each.key]
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  for_each                = local.students
  bucket                  = aws_s3_bucket.athena_results[each.key].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  for_each = local.students
  bucket   = aws_s3_bucket.athena_results[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Athena workgroup (student policy can use it but not create it) ---

resource "aws_athena_workgroup" "student" {
  for_each      = local.students
  name          = "quicklabs-${each.key}-wg"
  force_destroy = true
  tags          = local.student_tags[each.key]

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results[each.key].id}/results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

# --- Student IAM user + console password ---

resource "aws_iam_user" "student" {
  for_each      = local.students
  name          = "quicklabs-${each.key}"
  force_destroy = true
  tags          = local.student_tags[each.key]
}

resource "aws_iam_user_login_profile" "student" {
  for_each                = local.students
  user                    = aws_iam_user.student[each.key].name
  password_reset_required = true
  password_length         = 20

  # After `terraform import`, AWS doesn't return the password — TF state would
  # show it as null and trigger a regeneration on the next apply (rotating the
  # password the student has already received). Ignore changes once the profile
  # exists; if you ever need to rotate a password, taint the resource manually.
  lifecycle {
    ignore_changes = [password_length, password_reset_required]
  }
}

resource "aws_iam_policy" "student" {
  for_each    = local.students
  name        = "quicklabs-${each.key}-data-lake-sandbox"
  description = "Sandbox policy for Quicklabs student ${each.key}"
  policy      = local.rendered_user_policy[each.key]
  tags        = local.student_tags[each.key]
}

resource "aws_iam_user_policy_attachment" "student" {
  for_each   = local.students
  user       = aws_iam_user.student[each.key].name
  policy_arn = aws_iam_policy.student[each.key].arn
}

# --- Lab 2 add-on: Lambda ingestion policy ---
# Incremental over Lab 1. Adds SQS, Lambda, PassRole on the Lambda role,
# and Lambda CloudWatch Logs. Lab 1 access is untouched (each managed policy
# is its own Allow set — IAM permissions are the union across all attached).

resource "aws_iam_policy" "student_lab2" {
  for_each    = local.students
  name        = "quicklabs-${each.key}-lambda-ingestion"
  description = "Lab 2 add-on: SQS + Lambda ingestion actions for Quicklabs student ${each.key}"
  policy      = local.rendered_lab2_user_policy[each.key]
  tags        = local.student_tags[each.key]
}

resource "aws_iam_user_policy_attachment" "student_lab2" {
  for_each   = local.students
  user       = aws_iam_user.student[each.key].name
  policy_arn = aws_iam_policy.student_lab2[each.key].arn
}

# --- Lab 3 add-on: Lake Formation policy ---
# Incremental over Lab 1 + Lab 2. Adds LF grant/revoke/tag/filter actions +
# sts:AssumeRole on the analyst role.

resource "aws_iam_policy" "student_lakeformation" {
  for_each    = local.students
  name        = "quicklabs-${each.key}-lakeformation"
  description = "Lab 3 add-on: Lake Formation governance actions for Quicklabs student ${each.key}"
  policy      = local.rendered_lf_user_policy[each.key]
  tags        = local.student_tags[each.key]
}

resource "aws_iam_user_policy_attachment" "student_lakeformation" {
  for_each   = local.students
  user       = aws_iam_user.student[each.key].name
  policy_arn = aws_iam_policy.student_lakeformation[each.key].arn
}

# --- Per-student "data analyst" role (Day 2) ---
# Student grants LF permissions to this role in the lab, then assumes it
# via `aws sts assume-role` to verify the row/column filters and LF-Tag
# rules from a non-admin persona.

resource "aws_iam_role" "analyst" {
  for_each           = local.students
  name               = "quicklabs-${each.key}-data-analyst-role"
  assume_role_policy = local.rendered_analyst_trust_policy[each.key]
  tags               = local.student_tags[each.key]
}

resource "aws_iam_role_policy" "analyst_inline" {
  for_each = local.students
  name     = "quicklabs-analyst-athena-and-catalog-read"
  role     = aws_iam_role.analyst[each.key].id
  policy   = local.rendered_analyst_inline_policy[each.key]
}

# --- Lake Formation data-lake admins (account-wide setting) ---
# Make every student in the cohort an LF admin so they can register their own
# S3 locations and grant permissions on their own databases. This is broad on
# purpose — in the training account, all students share the catalog but each
# operates only within their `quicklabs_<u>_*` namespace.

resource "aws_lakeformation_data_lake_settings" "cohort" {
  admins = concat(
    [data.aws_caller_identity.current.arn],
    [for u in keys(local.students) : aws_iam_user.student[u].arn]
  )
  # Disable the implicit IAMAllowedPrincipals "everyone is allowed" grants
  # for newly created databases and tables. Without this, LF permissions
  # are bypassed and the row/column filters in the Day 2 lab will not
  # take effect.
  create_database_default_permissions {}
  create_table_default_permissions {}
}
