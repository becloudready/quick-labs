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

  raw_bucket     = "quicklabs-${var.username}-raw"
  curated_bucket = "quicklabs-${var.username}-curated"
  scripts_bucket = "quicklabs-${var.username}-scripts"
  database_name  = "quicklabs_${local.username_underscored}_lake"

  # Constructed, not data-sourced, to avoid needing iam:GetRole at apply time.
  glue_role_arn = "arn:aws:iam::${local.account_id}:role/quicklabs-${var.username}-glue-role"

  data_buckets = {
    raw     = aws_s3_bucket.raw.id
    curated = aws_s3_bucket.curated.id
    scripts = aws_s3_bucket.scripts.id
  }
}

# --- S3 buckets ---

resource "aws_s3_bucket" "raw" {
  bucket        = local.raw_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "curated" {
  bucket        = local.curated_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "scripts" {
  bucket        = local.scripts_bucket
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each                = local.data_buckets
  bucket                  = each.value
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "all" {
  for_each = local.data_buckets
  bucket   = each.value
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Upload ETL script + sample CSV ---

resource "aws_s3_object" "etl_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "oil_csv_to_parquet.py"
  source = "${path.module}/../oil_csv_to_parquet.py"
  etag   = filemd5("${path.module}/../oil_csv_to_parquet.py")
}

resource "aws_s3_object" "csv" {
  bucket = aws_s3_bucket.raw.id
  key    = "oil/Crude_Oil_historical_data.csv"
  source = var.csv_local_path
  etag   = filemd5(var.csv_local_path)
}

# --- Glue catalog database ---

resource "aws_glue_catalog_database" "lake" {
  name = local.database_name
}

# --- Glue crawlers (define here, run imperatively with `aws glue start-crawler`) ---

resource "aws_glue_crawler" "raw" {
  name          = "quicklabs-${var.username}-raw-crawler"
  role          = local.glue_role_arn
  database_name = aws_glue_catalog_database.lake.name
  table_prefix  = "raw_"

  s3_target {
    path = "s3://${aws_s3_bucket.raw.id}/oil/"
  }
}

resource "aws_glue_crawler" "curated" {
  name          = "quicklabs-${var.username}-curated-crawler"
  role          = local.glue_role_arn
  database_name = aws_glue_catalog_database.lake.name
  table_prefix  = "curated_"

  s3_target {
    path = "s3://${aws_s3_bucket.curated.id}/oil/"
  }
}

# --- Glue ETL job (run imperatively with `aws glue start-job-run`) ---

resource "aws_glue_job" "oil_etl" {
  name              = "quicklabs-${var.username}-oil-etl"
  role_arn          = local.glue_role_arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  # Default is 1 — students hit ConcurrentRunsExceededException after a
  # double-click before the previous run finishes. 3 absorbs accidents
  # without letting a runaway loop balloon DPU-hour cost.
  execution_property {
    max_concurrent_runs = 3
  }

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.id}/${aws_s3_object.etl_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--source_path"                      = "s3://${aws_s3_bucket.raw.id}/oil/Crude_Oil_historical_data.csv"
    "--target_path"                      = "s3://${aws_s3_bucket.curated.id}/oil/"
  }
}
