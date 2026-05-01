provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "Quicklabs"
      Lab     = "aws-data-lake"
      Student = var.username
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  username_underscored = replace(var.username, "-", "_")
  account_id           = data.aws_caller_identity.current.account_id

  policies_dir = "${path.module}/.."

  # The JSON files use {USERNAME}, {USERNAME_UNDERSCORED}, {ACCOUNT_ID} placeholders
  # so the same files work for both the bash setup and Terraform. We use replace()
  # rather than templatefile() because the policies contain ${aws:RequestedRegion}
  # IAM policy variables that would conflict with TF interpolation.
  # Minified via jsonencode(jsondecode(...)) — the user policy is ~6KB pretty-
  # printed, ~4.3KB minified. Inline user policies are capped at 2048 bytes;
  # managed policies at 6144. We use managed for headroom and minify anyway.
  rendered_user_policy = jsonencode(jsondecode(replace(replace(replace(
    file("${local.policies_dir}/student-user-policy.json"),
    "{USERNAME_UNDERSCORED}", local.username_underscored),
    "{USERNAME}", var.username),
  "{ACCOUNT_ID}", local.account_id)))

  rendered_glue_trust_policy = file("${local.policies_dir}/glue-role-trust-policy.json")

  rendered_glue_inline_policy = jsonencode(jsondecode(replace(replace(replace(
    file("${local.policies_dir}/glue-role-inline-policy.json"),
    "{USERNAME_UNDERSCORED}", local.username_underscored),
    "{USERNAME}", var.username),
  "{ACCOUNT_ID}", local.account_id)))
}

# --- Glue service role (assumed by crawlers and jobs run by the student) ---

resource "aws_iam_role" "glue" {
  name               = "quicklabs-${var.username}-glue-role"
  assume_role_policy = local.rendered_glue_trust_policy
}

resource "aws_iam_role_policy_attachment" "glue_managed" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_inline" {
  name   = "quicklabs-bucket-and-catalog-scope"
  role   = aws_iam_role.glue.id
  policy = local.rendered_glue_inline_policy
}

# --- Athena results bucket (workgroup writes query output here) ---

resource "aws_s3_bucket" "athena_results" {
  bucket        = "quicklabs-${var.username}-athena-results"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Athena workgroup (student policy can use it but not create it) ---

resource "aws_athena_workgroup" "student" {
  name          = "quicklabs-${var.username}-wg"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

# --- Student IAM user + console password ---

resource "aws_iam_user" "student" {
  name          = "quicklabs-${var.username}"
  force_destroy = true
}

resource "aws_iam_user_login_profile" "student" {
  user                    = aws_iam_user.student.name
  password_reset_required = true
  password_length         = 20
}

resource "aws_iam_policy" "student" {
  name        = "quicklabs-${var.username}-data-lake-sandbox"
  description = "Sandbox policy for Quicklabs student ${var.username}"
  policy      = local.rendered_user_policy
}

resource "aws_iam_user_policy_attachment" "student" {
  user       = aws_iam_user.student.name
  policy_arn = aws_iam_policy.student.arn
}
