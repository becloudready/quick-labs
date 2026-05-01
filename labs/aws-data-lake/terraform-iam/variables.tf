variable "username" {
  type        = string
  description = "Student username (lowercase, alphanumeric + hyphens). All resources are namespaced by this."
}

variable "region" {
  type        = string
  default     = "us-west-2"
  description = "Region the lab is locked to. Must match the policy's region condition."
}
