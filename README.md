# Quick Labs

**Open-source companion to BeCloudReady's Lab Engineering practice.**

Real, runnable cloud labs we've built for corporate L&amp;D, sales engineering, and partner enablement engagements — published here so the patterns are reusable. Each lab under [`labs/`](labs/) is a complete student-sandbox environment: IAM scoping, Terraform for the shared infrastructure, the student-facing walkthrough, and an admin walkthrough for the instructor running the cohort.

> If you're evaluating us for a custom training, demo, or GPU-cohort engagement, these labs are the work samples. The full service line lives at [becloudready.com/labs](https://becloudready.com/labs).

---

## What we ship

BeCloudReady designs custom cloud labs across three lanes. Each engagement produces an open-source companion lab in this repo when the client agrees to it.

| Lane | What it solves | Buyer |
|---|---|---|
| **Cloud Training Labs** | Per-student sandboxes for AWS / Azure / GCP / Databricks bootcamps — region-locked, namespace-scoped, teardown-clean | Corporate L&amp;D, training providers |
| **AI &amp; GPU Labs** | H100 / A100 cohorts on neo-cloud (Lambda Labs, Shadeform, RunPod) — 30–70% cheaper than hyperscaler equivalents | AI training programs, vendor partner enablement |
| **Sales Demo Environments** | Reproducible demo stacks for SE teams + partner programs | VPs of Sales Engineering, Partner Programs |

---

## Published labs

| Lab | Lane | Stack | Status |
|---|---|---|---|
| [`labs/aws-data-lake/`](labs/aws-data-lake/) | Cloud Training | S3 → Glue → Athena, IAM-scoped per student, region-locked to `us-west-2` | ✅ Shipped |
| `labs/databricks-text-to-sql/` | Cloud Training | Databricks workspace + Unity Catalog scoping for [`db-agent`](https://github.com/db-agent/db-agent) cohorts | 🚧 In progress |
| `labs/h100-cohort-jupyter/` | AI &amp; GPU | Per-student H100 + JupyterHub on neo-cloud, Terraform-provisioned | 🚧 In progress |

Each lab folder contains:

- `README.md` — folder map + setup script
- `student-lab.md` — what the student does (the actual hands-on doc)
- `admin-walkthrough.md` — what the instructor does end-to-end before students arrive
- `terraform-*` — per-cohort and per-student infrastructure (state files are gitignored)
- Policy JSONs, ETL scripts, sample data references

---

## Examples — legacy teaching content

The [`examples/`](examples/) directory holds material from earlier workshops and bootcamps (5+ years of teaching content). It runs independently of the `labs/` engagements:

- [`examples/linux-interviews/`](examples/linux-interviews/) — Linux interview question bank (networking, storage, LVM) plus Ansible playbooks that auto-grade candidate VMs
- [`examples/aws-ec2/`](examples/aws-ec2/), [`examples/aws-flask-app/`](examples/aws-flask-app/), [`examples/aws-rds/`](examples/aws-rds/) — boto3 + Flask reference snippets used in early AWS workshops
- [`examples/aws-private-subnet-jumpbox.md`](examples/aws-private-subnet-jumpbox.md) — VPC + jumpbox pattern write-up
- [`examples/digitalocean/`](examples/digitalocean/) — doctl + DO API recipes, plus reusable GitHub Actions for spinning up DO Kubernetes clusters

These stay in the repo as reference, not as actively-maintained labs.

---

## Want this for your team?

If your training program, sales-engineering team, or partner enablement track needs a custom lab — same pattern as what's in [`labs/`](labs/) but tailored to your stack and curriculum:

→ **Book a 30-min discovery call: [becloudready.com/labs](https://becloudready.com/labs)**

Typical engagement sizes:

- Cloud Training Labs — $15K–$30K per program
- AI &amp; GPU Labs — $20K–$40K per cohort
- Sales Demo Environments — $10K–$25K per template

---

## Repo layout

```
labs/                 — published case-study labs (one folder per engagement)
examples/             — legacy teaching content from earlier workshops
  digitalocean/
    github-actions/   — reusable DO Kubernetes setup workflows
```

---

## Contributing

This is primarily a portfolio repo for BeCloudReady's Lab Engineering practice, but useful issues and PRs are welcome:

- Found a policy gap or typo in a published lab? Open an issue or PR.
- Have an open-source lab that fits one of the three lanes? Reach out before opening a PR — we want labs we can stand behind.

---

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).

---

*Maintained by [BeCloudReady](https://becloudready.com) — Databricks Registered Partner. Community talks at [TorontoAI](https://torontoai.io).*
