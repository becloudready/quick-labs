variable "region" {
  description = "AWS region the lab is locked to."
  type        = string
  default     = "us-east-1"
}

variable "roster_csv" {
  description = "Path to the cohort roster CSV. Columns: username,full_name,email,github_username."
  type        = string
  default     = "students.csv"
}

variable "name_prefix" {
  description = "Prefix on every AWS resource the student owns. Combined with username: <prefix>-<username>-..."
  type        = string
  default     = "quicklabs"
}
