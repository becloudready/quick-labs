# QuickLabs

Hands-on workshop labs built by [BeCloudReady](https://becloudready.com) for engineering teams. Each lab is self-contained — pre-scoped IAM permissions, step-by-step walkthroughs, and sample data included. Drop into a workshop or run independently.

---

## Workshops

| Workshop | What you build | Stack |
|---|---|---|
| [`labs/aws-data-lake/`](labs/aws-data-lake/) | End-to-end data lake — raw ingestion → ETL → governance → CDC → analytics | S3, Glue, Athena, Lake Formation, Redshift, DMS, OpenSearch |
| [`labs/aws-iam-policy-lab/`](labs/aws-iam-policy-lab/) | Read, predict, and write IAM policies using a real sandbox policy as the textbook | IAM, CloudShell |
| [`labs/fullstack-aws/`](labs/fullstack-aws/) | Full-stack app sandbox with GitHub Copilot seats and namespace-scoped AWS access | EC2, Lambda, S3, DynamoDB, CloudFront, API Gateway |
| [`labs/databricks-db-agent-lakebase/`](labs/databricks-db-agent-lakebase/) | Text-to-SQL agent backed by Lakebase (Postgres), Databricks Unity Catalog, and a self-hosted vLLM endpoint | Databricks, Delta Lake, vLLM |

### AWS Data Lake — 6-lab curriculum

Labs 1–3 build on each other. Labs 4–6 are standalone.

| Lab | Topic |
|---|---|
| Lab 1 | S3 · Glue Crawler · Glue ETL (PySpark) · Athena |
| Lab 2 | Event-driven ingestion — S3 → SQS → Lambda |
| Lab 3 | Data governance — Lake Formation row/column/tag-based access control |
| Lab 4 | Redshift Serverless · federated query from Aurora RDS |
| Lab 5 | Change Data Capture — Postgres → DMS → S3 or Postgres target |
| Lab 6 | OpenSearch — ingestion, search, and dashboards |

---

## About

[BeCloudReady](https://becloudready.com) is a Databricks Registered Partner that builds and delivers cloud workshops for engineering teams. We run community workshops at [TorontoAI](https://torontoai.io).

| | |
|---|---|
| **Cloud Workshops** | Per-student AWS / Azure / GCP / Databricks sandboxes — region-locked, namespace-scoped, teardown-clean |
| **AI & GPU Labs** | H100 / A100 cohorts on neo-cloud (Lambda Labs, Shadeform, RunPod) — 30–70% cheaper than hyperscaler on-demand |
| **Sales Demo Environments** | Reproducible demo stacks for SE teams and partner programs |

**Need a workshop for your team?**
→ [becloudready.com/labs](https://becloudready.com/labs) · [Book a call](https://calendly.com/kchandank/30-mins-meeting)

---

## Contributing

Found a bug or a gap in a published lab? Issues and PRs are welcome.
Have a lab that fits one of the tracks above? Reach out before opening a PR.

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).
