output "console_url" {
  value = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "region" {
  value = var.region
}

# Per-student credentials, keyed by username from the CSV.
# Retrieve with: terraform output -json students | jq .
output "students" {
  description = "Per-student credentials and resource handles. Sensitive — contains plaintext passwords."
  sensitive   = true
  value = {
    for u, s in local.students : u => {
      username              = aws_iam_user.student[u].name
      full_name             = try(s.full_name, "")
      email                 = try(s.email, "")
      console_url           = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
      console_password      = aws_iam_user_login_profile.student[u].password
      glue_role_arn         = aws_iam_role.glue[u].arn
      athena_workgroup      = aws_athena_workgroup.student[u].name
      athena_results_bucket = aws_s3_bucket.athena_results[u].id
    }
  }
}

# Convenience: a CSV file written next to the module that the admin can email
# row-by-row to students. Plaintext passwords — chmod 0600, gitignored.
resource "local_sensitive_file" "credentials" {
  filename        = "${path.module}/students-credentials.csv"
  file_permission = "0600"
  content = join("\n", concat(
    ["username,full_name,email,console_url,console_password,region,athena_workgroup"],
    [for u, s in local.students :
      format("%s,%s,%s,%s,%s,%s,%s",
        aws_iam_user.student[u].name,
        try(s.full_name, ""),
        try(s.email, ""),
        "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console",
        aws_iam_user_login_profile.student[u].password,
        var.region,
        aws_athena_workgroup.student[u].name,
      )
    ],
  ))
}
