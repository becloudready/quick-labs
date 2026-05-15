# Student Lab — Postgres CDC to S3 via AWS DMS

End-to-end student lab: provision your own Postgres on RDS, load the oil
data into it, capture every INSERT/UPDATE/DELETE in real time via AWS DMS,
and watch the change records land in S3.

**This lab requires temporary admin access** to your AWS account (the
instructor will grant it for the session). RDS parameter groups, DMS
replication instances, and IAM service roles all need permissions beyond
the standard `quicklabs-studentN` policies.

Replace `<U>` throughout with your username digit (e.g. `8` for
`quicklabs-student8`).

---

## What you'll build

```
  ┌─────────────────────┐    write-ahead log     ┌──────────────────────┐
  │ RDS Postgres        │ ─────────────────────▶ │ DMS replication      │
  │ oil-db-<U>          │   (logical decoding)   │ instance             │
  │ public.crude_oil_   │                        │ oil-cdc-rep-<U>      │
  │ daily               │                        └──────────┬───────────┘
  └─────────────────────┘                                   │
              ▲                                              │ writes batched
              │ INSERT / UPDATE / DELETE                    │ CDC files (I/U/D)
              │ (you, via psql)                             ▼
                                                ┌──────────────────────┐
                                                │ s3://quicklabs-      │
                                                │ student<U>-curated/  │
                                                │ cdc/                 │
                                                └──────────────────────┘
```

By the end you'll have:

- Your own RDS Postgres with the 6,367-row oil table
- A working DMS CDC pipeline emitting `I` / `U` / `D` tagged files to S3
- A clear understanding of the gotchas: SSL, logical replication, plugin
  init, replication slots

---

## Prerequisites

- **Temp admin access granted** (your instructor attaches `AdministratorAccess` to your IAM user for this session)
- AWS console as `quicklabs-student<U>` in **us-west-2** (don't switch regions)
- Sign out and sign back in after admin access is attached, so your session picks up the new policy
- `psql` installed locally (`brew install libpq` on macOS, `apt install postgresql-client` on Linux)
- Repo cloned locally — you'll use the loader script from `lab-3-lake-formation/demo/rds-source/`

---

## Part 1 — Create your RDS Postgres with logical replication (15 min)

### 1.1 Create a custom parameter group

**RDS console → Parameter groups → Create parameter group**

| Field | Value |
|---|---|
| Parameter group family | `postgres17` |
| Type | DB parameter group |
| Group name | `oil-cdc-pg-<U>` |
| Description | `Postgres + logical replication for student<U>` |

Open the new group → search `rds.logical_replication` → **Edit parameters** → set value to `1` → **Save**.

### 1.2 Create the RDS instance

**RDS console → Databases → Create database**

| Field | Value |
|---|---|
| Creation method | Standard create |
| Engine | PostgreSQL |
| Version | **17.x** (do NOT pick 18.x — DMS has version-lag for the newest PG major) |
| Templates | Free tier (or Dev/Test) |
| DB instance identifier | `oil-db-<U>` |
| Master username | `postgres` |
| Master password | pick a strong one, write it down |
| DB instance class | `db.t3.micro` |
| Storage | 20 GB gp3, no autoscaling |
| Public access | **Yes** |
| VPC security group | Create new → `oil-db-sg-<U>` |
| Initial database name | (leave blank — we'll create it) |
| Backup retention | 0 days |
| Enhanced monitoring | Off |
| **DB parameter group (under Additional configuration)** | **`oil-cdc-pg-<U>`** (THIS is the critical part) |

Click **Create database**. Provisioning takes ~6 minutes.

### 1.3 Edit the security group inbound rules

While RDS provisions, **EC2 console → Security Groups → `oil-db-sg-<U>` → Edit inbound rules**. Add two rules:

| Type | Protocol | Port | Source | Why |
|---|---|---|---|---|
| PostgreSQL | TCP | 5432 | My IP | Your laptop's psql access |
| PostgreSQL | TCP | 5432 | **The SG itself** (`sg-...`) | So the DMS replication instance can reach Postgres |

### 1.4 Wait for `in-sync` and verify logical replication

Once the instance shows **Available**, run from your laptop:

```bash
aws rds describe-db-instances --region us-west-2 --db-instance-identifier oil-db-<U> \
  --query 'DBInstances[0].DBParameterGroups[0]' --output json
```

Status must be `"ParameterApplyStatus": "in-sync"`. If it says `pending-reboot`, reboot:

```bash
aws rds reboot-db-instance --region us-west-2 --db-instance-identifier oil-db-<U>
aws rds wait db-instance-available --region us-west-2 --db-instance-identifier oil-db-<U>
```

Then re-check status. Don't proceed until `in-sync`.

---

## Part 2 — Load the oil data (3 min)

```bash
export RDSHOST=oil-db-<U>.xxx.us-west-2.rds.amazonaws.com  # copy the actual endpoint from RDS console
export PGPASSWORD=<your-postgres-password>

cd lab-3-lake-formation/demo/rds-source
./load_oil.sh
```

This downloads the RDS CA bundle, creates database `oil`, applies the
schema (CREATE TABLE with `loaded_at` column + trigger), and `\copy`s the
6,367 rows in.

Final output should be:

```
 rows | first_day  |  last_day
------+------------+------------
 6367 | 2000-08-23 | 2025-12-31
```

Verify `wal_level`:

```bash
psql "host=$RDSHOST port=5432 dbname=oil user=postgres sslmode=verify-full sslrootcert=./global-bundle.pem"
```

```sql
SHOW wal_level;
-- must return: logical (not "replica")

SHOW max_replication_slots;
-- must be >= 1 (default is usually 10)
```

If `wal_level` says `replica`, the parameter group isn't applied. Go back
to step 1.4.

### 2.1 Confirm the user has replication privilege

```sql
SELECT usename, userepl FROM pg_user WHERE usename = 'postgres';
-- userepl must be 't' (true)
```

If false:

```sql
ALTER USER postgres WITH REPLICATION;
```

---

## Part 3 — DMS S3-writer IAM role (1 min — console auto-creates it)

DMS needs an IAM role with write access to your S3 bucket. **You don't have
to create this manually** — when you configure the S3 target endpoint in
Part 5.2, the DMS console offers a **"Create new IAM role"** link that
creates the role + inline policy in one click. Use that.

If you'd rather pre-create the role (for repeatable scripted setups,
or to avoid the wizard side-trip), here's the manual path. Otherwise skip
to Part 4.

<details>
<summary><b>Manual creation (optional)</b></summary>

**IAM console → Roles → Create role**

| Field | Value |
|---|---|
| Trusted entity type | AWS service |
| Use case | **DMS** |
| Role name | `dms-cdc-s3-role-<U>` |

Skip the AWS-managed policies dropdown, click Next → **Create role**.

Open the role → **Add permissions → Create inline policy** → JSON tab:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"],
    "Resource": [
      "arn:aws:s3:::quicklabs-student<U>-curated",
      "arn:aws:s3:::quicklabs-student<U>-curated/*"
    ]
  }]
}
```

Save as `dms-s3-inline`. Then in Part 5.2 use this role ARN directly
instead of clicking "Create new IAM role."

</details>

---

## Part 4 — Create the DMS replication instance (10 min)

**DMS console → Replication instances → Create replication instance**

| Field | Value |
|---|---|
| Name | `oil-cdc-rep-<U>` |
| Instance class | `dms.t3.micro` (cheapest, free tier eligible) |
| Engine version | latest |
| Allocated storage | 20 GB |
| VPC | **same VPC as your RDS** |
| Multi-AZ | dev or non-prod (single AZ) |
| Publicly accessible | **No** |

Provisioning takes ~5 minutes. Move on to the endpoints while it provisions.

---

## Part 5 — Create the source and target endpoints (5 min)

### 5.1 Source endpoint (Postgres)

**DMS console → Endpoints → Create endpoint**

| Field | Value |
|---|---|
| Endpoint type | **Source** |
| Endpoint identifier | `oil-source-pg-<U>` |
| Source engine | PostgreSQL |
| Server name | your RDS endpoint (e.g. `oil-db-<U>.xxx.us-west-2.rds.amazonaws.com`) |
| Port | 5432 |
| Database name | `oil` |
| User name | `postgres` |
| Password | your password |
| **SSL mode** | **`require`** — NOT `none` (RDS rejects unencrypted) |

**Test connection** (pick `oil-cdc-rep-<U>` as the rig). Must say "Successfully connected" before continuing.

**Common error here:** `no pg_hba.conf entry for host ... no encryption` means SSL mode is still `none`. Modify the endpoint, change to `require`, retest.

### 5.2 Target endpoint (S3)

**DMS console → Endpoints → Create endpoint**

| Field | Value |
|---|---|
| Endpoint type | **Target** |
| Endpoint identifier | `oil-target-s3-<U>` |
| Target engine | **Amazon S3** |
| IAM role ARN | Click **"Create new IAM role"** — the console creates one with the right permissions. (Or paste the ARN of `dms-cdc-s3-role-<U>` if you pre-created it in Part 3.) |
| Bucket name | `quicklabs-student<U>-curated` |
| Bucket folder | `cdc` (or any name you want — no `dms_` prefix or other naming requirement per [AWS DMS docs](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.S3.html); DMS will create `{bucketFolder}/{schema}/{table}/` underneath automatically) |

**Endpoint settings → Wizard mode:**

| Setting | Value |
|---|---|
| `dataFormat` | `csv` |
| `includeOpForFullLoad` | `true` |
| `cdcInsertsAndUpdates` | `true` |
| `timestampColumnName` | `cdc_ts` |

**Test connection.** Must pass.

---

## Part 6 — Create the CDC task (3 min)

**DMS console → Database migration tasks → Create task**

| Field | Value |
|---|---|
| Task identifier | `oil-cdc-task-<U>` |
| Replication instance | `oil-cdc-rep-<U>` |
| Source endpoint | `oil-source-pg-<U>` |
| Target endpoint | `oil-target-s3-<U>` |
| **Migration type** | **Replicate data changes only** (CDC only) |
| Start task on create | **Yes** |
| Table mappings (Wizard) | Schema `public`, source table `crude_oil_daily`, action **Include** |

Click **Create task**. Wait ~30-60 seconds. Status should move from `Creating` → `Starting` → `Replication ongoing`.

If status goes to `Failed`, check `Last error message` on the task detail page. Common error: `Unable to use plugins to establish logical replication`. Fix path:

1. Re-check that `SHOW wal_level;` returns `logical` (see Part 1.4 and Part 2)
2. Drop any stale replication slots: `SELECT slot_name, plugin, active FROM pg_replication_slots;` then `SELECT pg_drop_replication_slot('slot_name');`
3. Restart the task (Actions → Restart/Resume)

---

## Part 7 — Watch CDC in action (5 min)

Open two browser tabs / windows:

- **Tab 1:** S3 console → `quicklabs-student<U>-curated` → `cdc/` folder. Empty at start.
- **Tab 2 / psql window:** ready to run statements

### 7.1 Insert a "new trading day"

```sql
INSERT INTO public.crude_oil_daily (trade_ts, open, high, low, close, volume, ticker, name)
VALUES ('2026-06-01 00:00:00-04', 75.00, 76.50, 74.80, 75.90, 250000, 'CL=F', 'Crude Oil Futures (CL=F)');
```

Wait ~10-30 seconds, refresh S3. A file appears under
`cdc/oil/public/crude_oil_daily/`. Open it. The row is prefixed with `I`
(Insert) and a `cdc_ts` timestamp.

### 7.2 Update the row

```sql
UPDATE public.crude_oil_daily SET close = 999.99
WHERE trade_ts = '2026-06-01 00:00:00-04';
```

Refresh S3. Second file, prefixed `U`. Contains before-image + after-image.

### 7.3 Delete the row

```sql
DELETE FROM public.crude_oil_daily WHERE trade_ts = '2026-06-01 00:00:00-04';
```

Refresh S3. Third file, prefixed `D`.

### 7.4 Try a batch INSERT (shows DMS efficiency)

```sql
INSERT INTO public.crude_oil_daily (trade_ts, open, high, low, close, volume, ticker, name) VALUES
    ('2026-06-03 00:00:00-04', 80.00, 81.00, 79.80, 80.50, 200000, 'CL=F', 'Crude Oil Futures (CL=F)'),
    ('2026-06-04 00:00:00-04', 81.10, 82.50, 80.90, 82.20, 215000, 'CL=F', 'Crude Oil Futures (CL=F)'),
    ('2026-06-05 00:00:00-04', 82.40, 83.00, 81.70, 82.85, 198000, 'CL=F', 'Crude Oil Futures (CL=F)');
```

One INSERT statement, three rows → **one** S3 file containing all three records. DMS batches related changes rather than writing one file per row.

### 7.5 Check task statistics

**DMS console → Tasks → `oil-cdc-task-<U> → Table statistics`:**

You should see for `public.crude_oil_daily`: Inserts ≥ 4, Updates = 1, Deletes = 1.

---

## Part 8 (optional, 10 min) — Catalog the CDC output in Glue

So Athena can query the change records:

1. **Glue console → Crawlers → Create crawler**
   - Name: `oil-cdc-crawler-<U>`
   - Data source: S3 path `s3://quicklabs-student<U>-curated/cdc/oil/public/crude_oil_daily/`
   - IAM role: `quicklabs-student<U>-glue-role`
   - Target database: `quicklabs_student<U>_lake`
   - Table prefix: `cdc_`
2. Run the crawler. A new table `cdc_crude_oil_daily` appears.
3. In Athena:
   ```sql
   SELECT * FROM quicklabs_student<U>_lake.cdc_crude_oil_daily
   ORDER BY cdc_ts;
   ```
   You'll see all the I/U/D records with their operation flag and timestamp — the raw CDC stream queryable through Athena.

---

## Cleanup (REQUIRED before end of session)

Stop and delete everything you created — DMS resources cost real money per hour even when idle. Copy and adapt:

```bash
U=<your-username-digit>

# 1. Stop and delete the DMS task
TASK_ARN=$(aws dms describe-replication-tasks --region us-west-2 \
  --query "ReplicationTasks[?ReplicationTaskIdentifier=='oil-cdc-task-${U}'].ReplicationTaskArn" --output text)
aws dms stop-replication-task --region us-west-2 --replication-task-arn "$TASK_ARN" 2>/dev/null
sleep 10
aws dms delete-replication-task --region us-west-2 --replication-task-arn "$TASK_ARN" 2>/dev/null

# 2. Delete the endpoints
for ep in $(aws dms describe-endpoints --region us-west-2 \
    --query "Endpoints[?contains(EndpointIdentifier,'-${U}')].EndpointArn" --output text); do
  aws dms delete-endpoint --region us-west-2 --endpoint-arn "$ep"
done

# 3. Delete the replication instance
REP_ARN=$(aws dms describe-replication-instances --region us-west-2 \
  --query "ReplicationInstances[?ReplicationInstanceIdentifier=='oil-cdc-rep-${U}'].ReplicationInstanceArn" --output text)
aws dms delete-replication-instance --region us-west-2 --replication-instance-arn "$REP_ARN"

# 4. Delete the DMS-S3 IAM role (whichever name was used — manual pre-create OR console auto-create)
# Manual pre-create path:
aws iam delete-role-policy --role-name dms-cdc-s3-role-${U} --policy-name dms-s3-inline 2>/dev/null
aws iam delete-role --role-name dms-cdc-s3-role-${U} 2>/dev/null
# Console auto-create path — the console names it something like "dms-access-for-endpoint"
# Find it via: aws iam list-roles --query "Roles[?starts_with(RoleName,'dms-')].RoleName" --output text
# Delete with: aws iam delete-role --role-name <found-name> (after detaching its policies)

# 5. Delete the RDS instance (skip snapshot for the demo)
aws rds delete-db-instance --region us-west-2 \
  --db-instance-identifier oil-db-${U} \
  --skip-final-snapshot \
  --delete-automated-backups

# 6. (After RDS is fully deleted, ~5 min) delete the parameter group
aws rds delete-db-parameter-group --region us-west-2 --db-parameter-group-name oil-cdc-pg-${U}

# 7. Optionally delete the CDC files from S3
aws s3 rm s3://quicklabs-student${U}-curated/cdc/ --recursive
```

---

## Submission checklist

Submit one Markdown or PDF with:

- [ ] Endpoint of your RDS instance (proves it existed)
- [ ] Output of `SHOW wal_level;` showing `logical`
- [ ] DMS task screenshot showing `Replication ongoing` status
- [ ] Screenshot of the S3 `cdc/` folder showing at least 3 files (your I, U, D)
- [ ] Open one of the CSV files and paste the first few lines — the row should start with the operation flag (`I`/`U`/`D`)
- [ ] (Optional) Athena query result from Part 8 showing the CDC stream

---

## Troubleshooting reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `SHOW wal_level` returns `replica` after rebooting | Parameter group was touched again after the last reboot, silently resetting pending-reboot | Run `aws rds describe-db-instances ... --query '...DBParameterGroups'`; if `pending-reboot`, reboot again until `in-sync` |
| DMS Test connection: `no pg_hba.conf entry ... no encryption` | Source endpoint SSL mode is `none`; RDS only accepts TLS | Modify endpoint, set SSL mode to `require`, retest |
| DMS task error: `Unable to use plugins to establish logical replication` | `wal_level != logical` at runtime; OR stale replication slot blocking; OR Postgres user lacks REPLICATION | (1) verify `wal_level = logical` and `ParameterApplyStatus = in-sync`; (2) drop stale slots; (3) `ALTER USER postgres WITH REPLICATION;` |
| Task starts but Inserts = 0 and S3 stays empty | Normal for CDC-only mode with no source activity since task start | Run an INSERT in psql; file appears within ~30 sec |
| RDS provisioning succeeded but you can't connect via psql | Security group missing your laptop's IP as inbound rule on 5432 | EC2 console → SG → Edit inbound rules → add `My IP` for port 5432 |
| You created RDS on Postgres 18 and DMS fails on plugin init | DMS support lags new PG majors | Delete the instance, recreate on **Postgres 17**, redo Part 1 |
| Lab is over and your DMS instance is still running | You forgot the cleanup step | Run the cleanup script above immediately — `dms.t3.micro` is ~$0.04/hr |

---

## Why this matters (the takeaway)

CDC is the difference between a data lake that's **stale** and a data lake that's **operational**.

- **Batch ETL** dumps your source table every N hours. Latency = N hours, deletes are invisible (you can't tell a row was deleted, just that it's absent).
- **CDC** reads your source's write-ahead log directly. Latency = seconds. Every operation is captured, with operation type. Downstream systems can replay exactly what happened.

Combined with Lake Formation (which you learned earlier today), CDC + LF
gives you **freshness and governance** in the same data lake — the CDC
files land in an LF-registered location, inheriting the same column/row/tag
access rules as any other table.
