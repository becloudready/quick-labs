###############################################################################
# Full-Stack on AWS — per-cohort IAM bootstrap
#
# Reads students.csv, creates one IAM user per row with:
#   - console login (temporary password, must change on first login)
#   - inline sandbox policy rendered from ../student-user-policy.json
#
# Run once per cohort. Idempotent on `username` — adding/removing rows in the
# CSV and re-applying is the supported workflow.
###############################################################################

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  roster_raw = csvdecode(file(var.roster_csv))

  # username keyed, drop blank rows
  students = {
    for s in local.roster_raw : s.username => s
    if try(s.username, "") != ""
  }
}

# --- IAM user per student ----------------------------------------------------

resource "aws_iam_user" "student" {
  for_each = local.students

  name = "${var.name_prefix}-${each.key}"
  tags = {
    full_name        = try(each.value.full_name, "")
    email            = try(each.value.email, "")
    github_username  = try(each.value.github_username, "")
    cohort           = "fullstack-aws"
  }
}

resource "aws_iam_user_login_profile" "student" {
  for_each = aws_iam_user.student

  user                    = each.value.name
  password_reset_required = true

  # TODO: encrypt with a PGP key per student, or write to a sealed secret store.
  # For now Terraform generates a one-time password in state — handle state file
  # accordingly (the parent README's `students-credentials.csv` is gitignored).
}

# --- Sandbox policy ----------------------------------------------------------

resource "aws_iam_user_policy" "sandbox" {
  for_each = aws_iam_user.student

  name = "${var.name_prefix}-${each.key}-fullstack-sandbox"
  user = each.value.name

  policy = replace(
    replace(
      file("${path.module}/../student-user-policy.json"),
      "{USERNAME}", each.key
    ),
    "{ACCOUNT_ID}", data.aws_caller_identity.current.account_id
  )
}

# --- Credentials CSV (sensitive) --------------------------------------------
#
# Writes a one-row-per-student CSV that the admin uses to send welcome emails.
# Path is at the repo root and gitignored.

resource "local_sensitive_file" "credentials" {
  filename        = "${path.module}/../../../students-credentials.csv"
  file_permission = "0600"

  content = join("\n", concat(
    ["username,full_name,email,console_url,console_password,region"],
    [
      for u, s in local.students :
      join(",", [
        u,
        try(s.full_name, ""),
        try(s.email, ""),
        "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console",
        aws_iam_user_login_profile.student[u].password,
        var.region,
      ])
    ]
  ))
}
