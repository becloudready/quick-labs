# DigitalOcean Kubernetes — GitHub Actions snippets

Two reusable bits from older bootcamp / demo work, kept here for reference.

| File | Type | Use |
|---|---|---|
| `create-digitalocean-k8s-cluster.yml` | `workflow_dispatch` workflow | Manually-triggered job that spins up a DO Kubernetes cluster. Drop into `.github/workflows/` of a target repo and run from the Actions tab. |
| `setup-digitalocean-k8s-cluster.action.yml` | Composite action | Same logic, packaged as a reusable composite action. Drop into a target repo as `.github/actions/setup-do-k8s/action.yml` and call from any workflow with `uses: ./.github/actions/setup-do-k8s`. |

Both expect a `digitalocean_token` input — provide it via `secrets.DIGITALOCEAN_TOKEN`, never inline.
