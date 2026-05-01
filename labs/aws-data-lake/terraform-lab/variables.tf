variable "username" {
  type        = string
  description = "Student username — must match the one used by terraform-iam."
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "csv_local_path" {
  type        = string
  description = "Local path to Crude_Oil_historical_data.csv (Kaggle download)."
}
