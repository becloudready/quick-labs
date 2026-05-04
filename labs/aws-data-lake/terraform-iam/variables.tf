variable "students_csv" {
  type        = string
  default     = "students.csv"
  description = "Path to CSV roster. Required column: username (lowercase, alphanumeric + hyphens). Optional: full_name, email."
}

variable "region" {
  type        = string
  default     = "us-west-2"
  description = "Region the lab is locked to. Must match the policy's region condition."
}
