output "console_url" {
  value = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "region" {
  value = var.region
}

# Per-student credentials, keyed by username actually present in state.
# Iteration is over `aws_iam_user.student` (not `local.students`) so this
# evaluates cleanly during partial state — e.g., while `import-existing.sh`
# is walking the roster, only imported students appear in the output.
# After a full apply, all rows are present.
#
# Retrieve with: terraform output -json students | jq .
output "students" {
  description = "Per-student credentials and resource handles. Sensitive — contains plaintext passwords."
  sensitive   = true
  value = {
    for u, user in aws_iam_user.student : u => {
      username              = user.name
      full_name             = try(local.students[u].full_name, "")
      email                 = try(local.students[u].email, "")
      console_url           = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
      # Imported login profiles return "" — AWS doesn't expose the password
      # after creation. Newly-created profiles populate this from TF.
      console_password      = try(aws_iam_user_login_profile.student[u].password, "")
      glue_role_arn         = try(aws_iam_role.glue[u].arn, null)
      lambda_role_arn       = try(aws_iam_role.lambda[u].arn, null)
      analyst_role_arn      = try(aws_iam_role.analyst[u].arn, null)
      athena_workgroup      = try(aws_athena_workgroup.student[u].name, null)
      athena_results_bucket = try(aws_s3_bucket.athena_results[u].id, null)
    }
  }
}

# Convenience: a CSV file written next to the module that the admin can email
# row-by-row to students. Plaintext passwords — chmod 0600, gitignored.
#
# Only writes rows for students whose IAM user is present in state, so the
# file is meaningful during partial-import bootstrap and after full apply.
resource "local_sensitive_file" "credentials" {
  filename        = "${path.module}/students-credentials.csv"
  file_permission = "0600"
  content = join("\n", concat(
    ["username,full_name,email,console_url,console_password,region,athena_workgroup"],
    [for u, user in aws_iam_user.student :
      format("%s,%s,%s,%s,%s,%s,%s",
        user.name,
        try(local.students[u].full_name, ""),
        try(local.students[u].email, ""),
        "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console",
        # Imported login profiles return null for password (AWS doesn't surface
        # it post-creation). `try()` doesn't catch null — only errors — so we
        # explicit-check. Empty column means "must reset for this student".
        aws_iam_user_login_profile.student[u].password == null ? "" : aws_iam_user_login_profile.student[u].password,
        var.region,
        try(aws_athena_workgroup.student[u].name, ""),
      )
    ],
  ))
}
