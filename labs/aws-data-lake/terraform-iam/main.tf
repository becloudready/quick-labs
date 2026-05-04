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
      file("${local.policies_dir}/student-user-policy.json"),
      "{USERNAME_UNDERSCORED}", replace(u, "-", "_")),
      "{USERNAME}", u),
    "{ACCOUNT_ID}", local.account_id)))
  }

  rendered_glue_trust_policy = file("${local.policies_dir}/glue-role-trust-policy.json")

  rendered_glue_inline_policy = {
    for u, s in local.students : u => jsonencode(jsondecode(replace(replace(replace(
      file("${local.policies_dir}/glue-role-inline-policy.json"),
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
  assume_role_policy = local.rendered_glue_trust_policy
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
