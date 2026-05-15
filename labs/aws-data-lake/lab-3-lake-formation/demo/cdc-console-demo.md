# CDC Console Demo — Postgres → DMS → S3

Console-only walkthrough of Change Data Capture using the same oil data.
INSERT / UPDATE / DELETE rows in Postgres, watch the change records land in
S3 within seconds.

Producer is `quicklabs-student8` (you), same as the LF demo. Reuses the RDS
Postgres + `crude_oil_daily` table from the LF demo prerequisites.

| Variable | Value |
|---|---|
| RDS instance | `database-1` (Postgres 17, single instance, publicly accessible) |
| RDS endpoint | `<your-rds-endpoint>.us-west-2.rds.amazonaws.com:5432` |
| Database | `oil` |
| Source table | `public.crude_oil_daily` |
| Source S3 (CDC output) | `s3://quicklabs-student8-curated/cdc/` |
| Account ID | `<ACCOUNT_ID>` (e.g. `123456789012`) |
| Region | `us-west-2` |

---

## Prerequisites (verify, 2 min)

1. **RDS Postgres `database-1`** is up and the `oil` database has
   `public.crude_oil_daily` with 6,367 rows (from the LF demo loader script
   `demo/rds-source/load_oil.sh`).
2. You can `psql` into it as `postgres`.

---

## One-time setup (15 min — do BEFORE class)

### Setup 1 — Enable logical replication on RDS Postgres

DMS needs logical replication slots, which require `rds.logical_replication = 1`.

**RDS console → Parameter groups → Create parameter group**

| Field | Value |
|---|---|
| Parameter group family | match your instance engine version (e.g. `postgres17`, `postgres18`) |
| Name | `oil-cdc-pgNN` (substitute the version) |

Create. Open the group → search `rds.logical_replication` → **Edit** → set to `1` → Save.

**RDS → Databases → `database-1` → Modify** → Additional configuration → DB parameter group → your new group → **Continue** → **Apply immediately** → Modify.

**Reboot the instance** (parameter is `static`, requires reboot): RDS → Actions → Reboot.

**Critical post-reboot check** — the parameter group must show `in-sync` at the instance level, not just "I rebooted":

```bash
aws rds describe-db-instances --region us-west-2 --db-instance-identifier database-1 \
  --query 'DBInstances[0].DBParameterGroups[0]' --output json
```

Status must be `"ParameterApplyStatus": "in-sync"`. If it's still `pending-reboot`, the parameter binding hasn't taken — reboot again. Don't proceed until it's `in-sync`.

Then verify in psql:

```sql
SHOW wal_level;
-- must return: logical (NOT replica)
```

> **If `wal_level` still shows `replica` even though the param group is `in-sync`:** the parameter group was modified again *after* your last reboot, which silently reset the pending-reboot flag. The `pending-reboot` clock restarts on *any* parameter-group touch — even toggling a value back to its existing state. Reboot once more after the most recent modification, full stop.

### Setup 2 — Create the IAM role DMS will use to write to S3

**IAM console → Roles → Create role**

- Trusted entity: **AWS service** → **DMS**
- Permissions: Create a custom inline policy with `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`, `s3:GetBucketLocation` on `arn:aws:s3:::quicklabs-student8-curated` and `arn:aws:s3:::quicklabs-student8-curated/*`.
- Role name: `dms-cdc-s3-role`

### Setup 3 — Create the DMS replication instance

**DMS console → Replication instances → Create replication instance**

| Field | Value |
|---|---|
| Name | `oil-cdc-instance` |
| Instance class | `dms.t3.micro` (free tier eligible) |
| Engine version | latest |
| Allocated storage | 20 GB |
| VPC | same VPC as your RDS |
| Multi-AZ | dev or non-prod (single AZ) |
| Publicly accessible | No |

Create. Provisioning takes ~5 minutes.

### Setup 4 — Create the source endpoint (Postgres)

**DMS console → Endpoints → Create endpoint**

| Field | Value |
|---|---|
| Endpoint type | **Source** |
| Endpoint identifier | `oil-source-postgres` |
| Source engine | **PostgreSQL** |
| Server name | `<your-rds-endpoint>.us-west-2.rds.amazonaws.com` |
| Port | `5432` |
| Database name | `oil` |
| User name | `postgres` |
| Password | (your password) |
| **SSL mode** | **`require`** (must NOT be `none` — RDS rejects unencrypted connections) |

Click **Test connection** (pick `oil-cdc-instance` as the test rig). Must pass.

> **Common failure here:** `no pg_hba.conf entry for host ... no encryption`.
> That means SSL mode is still `none`. Modify the endpoint, change SSL mode
> to `require`, retest.

### Setup 5 — Create the target endpoint (S3)

**DMS console → Endpoints → Create endpoint**

| Field | Value |
|---|---|
| Endpoint type | **Target** |
| Endpoint identifier | `oil-target-s3` |
| Target engine | **Amazon S3** |
| IAM role ARN | `arn:aws:iam::<ACCOUNT_ID>:role/dms-cdc-s3-role` |
| Bucket name | `quicklabs-student8-curated` |
| Bucket folder | `cdc` |

Endpoint settings (under **Endpoint settings → Wizard mode**):

| Setting | Value |
|---|---|
| `dataFormat` | `csv` (simpler than parquet for the demo — easier to read) |
| `includeOpForFullLoad` | `true` |
| `cdcInsertsAndUpdates` | `true` |
| `timestampColumnName` | `cdc_ts` |

Test connection. Must pass.

### Setup 6 — Grant the Postgres user replication privileges

In psql:

```sql
\c oil
ALTER USER postgres WITH REPLICATION;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
```

(`postgres` user usually has replication already, but make it explicit so
DMS doesn't complain about missing privileges.)

### Setup 7 — Create the CDC task

**DMS console → Database migration tasks → Create task**

| Field | Value |
|---|---|
| Task identifier | `oil-cdc-task` |
| Replication instance | `oil-cdc-instance` |
| Source endpoint | `oil-source-postgres` |
| Target endpoint | `oil-target-s3` |
| **Migration type** | **Replicate data changes only** (CDC only — no full load) |
| Start task on create | **No** (we'll start it live during the demo) |
| Table mappings | Wizard: Schema `public`, Source table `crude_oil_daily`, Action **Include** |

Create. Task status should be `Ready`.

**Setup is complete.** Total runtime cost: ~$0.04/hr for the replication instance. Stop the task between sessions.

---

## Demo (5 minutes, live)

### 1. Show baseline — current row count in psql

```bash
export RDSHOST=<your-rds-endpoint>.us-west-2.rds.amazonaws.com
psql "host=$RDSHOST port=5432 dbname=oil user=postgres sslmode=verify-full sslrootcert=./global-bundle.pem"
```

```sql
SELECT COUNT(*) FROM public.crude_oil_daily;
-- 6367 (or wherever you're at)
```

### 2. Start the CDC task

**DMS console → Tasks → `oil-cdc-task` → Actions → Start/resume task** → Start.

Wait ~30 seconds for it to enter `Replication ongoing` status.

### 3. Show that S3 is empty at the start

**S3 console → `quicklabs-student8-curated` → `cdc/` folder.** Should be empty or just have metadata files. Keep this tab open and refresh as you go.

### 4. Insert a "new trading day" — the audience watches

Back in psql:

```sql
INSERT INTO public.crude_oil_daily
    (trade_ts, open, high, low, close, volume, ticker, name)
VALUES
    ('2026-06-01 00:00:00-04', 75.00, 76.50, 74.80, 75.90, 250000, 'CL=F', 'Crude Oil Futures (CL=F)');
```

Refresh the S3 console. Within ~10 seconds, a new file appears under:

```
s3://quicklabs-student8-curated/cdc/oil/public/crude_oil_daily/
```

Click the file → **Open** → see the row, prefixed with `I` (Insert) and the
timestamp. **That's CDC working.**

### 5. Update one of the existing rows

```sql
UPDATE public.crude_oil_daily
SET close = 999.99
WHERE trade_ts = '2026-06-01 00:00:00-04';
```

Refresh S3. A second file appears — this one prefixed with `U` (Update),
containing both the old and new values of the row.

### 6. Delete the row

```sql
DELETE FROM public.crude_oil_daily WHERE trade_ts = '2026-06-01 00:00:00-04';
```

Refresh S3. Third file — prefixed with `D` (Delete).

### Consolidated copy-paste version

For when you want one block to paste into psql and watch S3 refresh between
each statement. Each statement is on its own line so you can run them
one-by-one (`\;` in psql submits the current line):

```sql
-- 1. INSERT — watch for an "I"-tagged file in S3
INSERT INTO public.crude_oil_daily (trade_ts, open, high, low, close, volume, ticker, name)
VALUES ('2026-06-01 00:00:00-04', 75.00, 76.50, 74.80, 75.90, 250000, 'CL=F', 'Crude Oil Futures (CL=F)');

-- 2. UPDATE — watch for a "U"-tagged file
UPDATE public.crude_oil_daily SET close = 999.99
WHERE trade_ts = '2026-06-01 00:00:00-04';

-- 3. DELETE — watch for a "D"-tagged file
DELETE FROM public.crude_oil_daily
WHERE trade_ts = '2026-06-01 00:00:00-04';
```

### Variant statements for re-running the demo

After running the demo once, the row for `2026-06-01` is gone (DELETE
happened). For a clean second run, use a different `trade_ts`:

```sql
-- second run — different trade_ts
INSERT INTO public.crude_oil_daily (trade_ts, open, high, low, close, volume, ticker, name)
VALUES ('2026-06-02 00:00:00-04', 78.20, 79.10, 77.50, 78.85, 310000, 'CL=F', 'Crude Oil Futures (CL=F)');

UPDATE public.crude_oil_daily SET close = 1234.56 WHERE trade_ts = '2026-06-02 00:00:00-04';

DELETE FROM public.crude_oil_daily WHERE trade_ts = '2026-06-02 00:00:00-04';
```

```sql
-- third run — different trade_ts, batch INSERT (shows DMS handling multiple rows in one statement)
INSERT INTO public.crude_oil_daily (trade_ts, open, high, low, close, volume, ticker, name) VALUES
    ('2026-06-03 00:00:00-04', 80.00, 81.00, 79.80, 80.50, 200000, 'CL=F', 'Crude Oil Futures (CL=F)'),
    ('2026-06-04 00:00:00-04', 81.10, 82.50, 80.90, 82.20, 215000, 'CL=F', 'Crude Oil Futures (CL=F)'),
    ('2026-06-05 00:00:00-04', 82.40, 83.00, 81.70, 82.85, 198000, 'CL=F', 'Crude Oil Futures (CL=F)');
```

(A multi-row INSERT produces a single S3 file containing all three rows — good for showing that DMS batches efficiently rather than emitting one file per row.)

Refresh S3. Third file — prefixed with `D` (Delete).

### 7. The talk track

> "Without CDC, the only way to know what changed in this database since
> the last batch was to compare row-by-row, or trust timestamps that may or
> may not exist on every row. DMS reads the Postgres write-ahead log directly
> — Postgres tells it 'here's exactly what changed' — and DMS writes those
> change records to S3 as files we can downstream into Glue, Redshift, or
> Iceberg in near real-time.
>
> Three operations: one insert, one update, one delete. Three S3 files, each
> tagged with the operation type. That's the entire CDC pattern."

---

## Stopping & cleanup

**Between demo sessions:** DMS console → Tasks → `oil-cdc-task` → Actions →
**Stop**. The replication instance still costs ~$0.04/hr while running, so:

**End of project:** DMS console → delete task, delete endpoints, delete
replication instance, delete IAM role, revert parameter group on the RDS
instance to the default (and reboot). Drop any CDC S3 files you don't want
in your data lake.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Test connection fails: `no pg_hba.conf entry for host ... no encryption` | DMS source endpoint SSL mode is `none`; RDS only accepts encrypted connections | Modify the source endpoint, set SSL mode to `require` |
| Test connection fails on source endpoint (other) | RDS SG doesn't allow inbound from DMS replication instance's SG | Add the DMS instance's SG as an inbound rule on port 5432 in the RDS SG |
| Test connection fails on target endpoint | DMS role missing S3 write perms | Re-check the inline policy on `dms-cdc-s3-role` |
| `wal_level` returns `replica` even after rebooting | Parameter group was modified again after the last reboot — pending-reboot flag reset silently | Run `aws rds describe-db-instances ... --query 'DBInstances[0].DBParameterGroups'` — if it says `pending-reboot`, reboot again until `in-sync` |
| Task fails: `Unable to use plugins to establish logical replication on source PostgreSQL instance` | Most common cause is `wal_level != logical` (param group still pending-reboot at instance level). Secondary: stale replication slot blocking, or Postgres user lacks REPLICATION | (1) verify `ParameterApplyStatus = in-sync` and `SHOW wal_level = logical`; (2) clean up stale slots with `SELECT pg_drop_replication_slot('slot_name')`; (3) `ALTER USER postgres WITH REPLICATION;` |
| Task starts but no files in S3 after INSERT | Same root cause as above (logical replication not active) | Same fix |
| Task errors `logical decoding requires a replication slot` | Postgres user doesn't have replication privilege | `ALTER USER postgres WITH REPLICATION;` |
| Files appear but task latency grows over time | Replication slot accumulates WAL — Postgres disk fills | Stop task properly (don't just delete it); orphaned slots hold WAL forever. Drop them with `pg_drop_replication_slot` if abandoned |
| Task fails on a brand-new Postgres major version (e.g. Postgres 18) | DMS support lags new Postgres majors | Check the AWS DMS supported-versions doc page. Fallback: recreate the RDS instance on the last fully supported version (e.g. Postgres 17) |

---

## Why this matters (slide-friendly closing)

CDC is what makes a data lake **operational** instead of **lagging**:

- **Batch ETL:** ingestion every N hours; queries see N-hour-stale data.
- **CDC:** ingestion within seconds of the source change; queries see near-real-time data.

The CDC pattern lets analytics workloads use the operational database as a
source without touching it directly — and without the latency penalty of
batch dumps. Combined with Lake Formation, you get **near-real-time AND
governed** — every CDC-produced file lands in an LF-registered location,
inheriting the same column/row/tag-based access rules you already grant.
