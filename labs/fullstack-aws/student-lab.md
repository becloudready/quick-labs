# Full-Stack on AWS — Student Onboarding

Welcome. By the end of this page you'll have:

1. Joined the GitHub org and activated Copilot
2. Signed in to the AWS console with your sandbox user
3. Confirmed you can create your first resource in your namespace

## 1 — GitHub

You should have received two emails from GitHub:

- **Org invite** to `becloudready` → click *Accept invitation*. You'll land on the `{TEAM_SLUG}` team page.
- **Copilot seat assignment** → no action needed; the seat is already active.

Verify Copilot is on:

```bash
# In a repo from the cohort team
code .
# Open any .ts / .py file — Copilot suggestions appear inline.
# If not: VS Code → Extensions → install "GitHub Copilot" → sign in with your GitHub account.
```

## 2 — AWS console

Your instructor will hand you (over a secure channel):

```
Console URL : https://{ACCOUNT_ID}.signin.aws.amazon.com/console
Username    : quicklabs-{your-username}
Password    : <temporary — you'll be forced to change it on first login>
Region      : us-east-1  (anything else is denied)
```

On sign-in:

- AWS will force a password change. Pick a strong one.
- The top-right region selector must read **US East (N. Virginia) us-east-1**. Anything else and most actions will be denied.

## 3 — Your namespace

Every resource you create must be named with the prefix `quicklabs-{your-username}-`. Examples:

- S3 bucket: `quicklabs-alice-uploads`
- Lambda function: `quicklabs-alice-api`
- DynamoDB table: `quicklabs-alice-users`

> TODO (instructor): list the exact services + naming sub-conventions for your curriculum here.

## 4 — Smoke test

> TODO: fill in once `student-user-policy.json` is finalized. Suggested checks:
> - Create an S3 bucket `quicklabs-{u}-test`, upload a file, delete it.
> - Try to create `random-bucket-name` — should be denied.
> - Switch region to `us-west-2`, open S3 — should be mostly empty / denied.

## Getting help

- Cohort questions: `#fullstack-cohort` Slack channel
- Stuck on AWS permissions: paste the full error (action + resource ARN) in Slack — your instructor will adjust the sandbox policy.
