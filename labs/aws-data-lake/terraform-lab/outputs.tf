output "raw_bucket" {
  value = aws_s3_bucket.raw.id
}

output "curated_bucket" {
  value = aws_s3_bucket.curated.id
}

output "scripts_bucket" {
  value = aws_s3_bucket.scripts.id
}

output "database" {
  value = aws_glue_catalog_database.lake.name
}

output "raw_crawler" {
  value = aws_glue_crawler.raw.name
}

output "curated_crawler" {
  value = aws_glue_crawler.curated.name
}

output "glue_job" {
  value = aws_glue_job.oil_etl.name
}

output "next_steps" {
  value = <<-EOT
    Resources are provisioned. Now run the imperative steps:

      USERNAME=${var.username}
      WORKGROUP=quicklabs-$${USERNAME}-wg

      # 1. Crawl the raw zone
      aws glue start-crawler --name ${aws_glue_crawler.raw.name}

      # 2. Run the ETL job (args are baked into the job's default_arguments)
      aws glue start-job-run --job-name ${aws_glue_job.oil_etl.name}

      # 3. Crawl the curated zone
      aws glue start-crawler --name ${aws_glue_crawler.curated.name}

      # 4. Query in Athena via workgroup $${WORKGROUP}
  EOT
}
