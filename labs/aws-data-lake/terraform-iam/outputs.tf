output "console_url" {
  value = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "username" {
  value = aws_iam_user.student.name
}

output "console_password" {
  value     = aws_iam_user_login_profile.student.password
  sensitive = true
  # Retrieve with: terraform output -raw console_password
}

output "region" {
  value = var.region
}

output "glue_role_arn" {
  value = aws_iam_role.glue.arn
}

output "athena_workgroup" {
  value = aws_athena_workgroup.student.name
}

output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results.id
}
