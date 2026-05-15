---

## Use case 3 — Lambda as the ETL layer (no Glue ETL, Redshift + S3 data lake)

**The constraint.** Your data platform is Redshift with S3 as the storage backend (the "Redshift lakehouse" shape). Glue ETL and Glue Crawlers are off the table — too opaque, too expensive, governance can't sign off, take your pick. The Glue **Data Catalog** is still fair game as a passive metadata store, because Spectrum and Athena both need somewhere to read the schema from. But every byte of compute has to be either Lambda or Redshift.

That means the Lambda job is no longer "copy a file" — it has to do the work Glue ETL would have done.

### What Lambda is responsible for

For each new file landing in raw, the function must:

1. **Read** the source object (CSV/JSON/whatever the producer drops).
2. **Validate** the rows against an **explicit, declared-in-code schema**. No schema-on-read tricks, no crawler inference — if the source breaks the contract, you reject the batch and DLQ it.
3. **Transform** to **Parquet with Snappy compression**. Redshift COPY loads Parquet 5–10× faster than CSV, and Spectrum scan cost drops by the same factor.
4. **Partition** by a business-relevant date column (e.g. `trade_date`, `event_date`). Write each partition to its own Hive-style prefix:
   ```
   s3://<curated>/<table>/year=YYYY/month=MM/day=DD/<file>.parquet
   ```
5. **Register the partition** with Glue Catalog using `glue:CreatePartition` (or `BatchCreatePartition` if multiple). This is the crawler replacement — Spectrum and Athena lookups go through the catalog, so without this step the new partition is invisible.
6. **Trigger Redshift COPY** (optional, depends on the consumer pattern) via the `redshift-data` API. Decouples ingest from query — Lambda doesn't block on the COPY, Redshift does its own thing.
7. **Tag the source object** `ingest-status=processed` so a retry doesn't re-process it. The same file landing twice (S3 redelivery, operator drag-drop, partner re-send) is a real thing.

### Spectrum vs. COPY — and why most orgs do both

The Glue catalog entry from step 5 makes the new partition queryable from Redshift **without** a COPY, via Spectrum. The COPY in step 6 loads the data into a native Redshift table.

| Pattern | Latency to query | $/query | When |
|---|---|---|---|
| Spectrum-only (skip step 6) | Sub-second | Pay per byte scanned | Cold data, ad-hoc, large fact tables |
| COPY-only (skip step 5) | Wait for COPY | Cheap once loaded | Hot data, dashboard-backed |
| Both | Best of both | Storage 2× | The realistic answer most orgs land on |

Reference handler — [`csv_to_parquet_curated.py`](lambda-code/csv_to_parquet_curated.py) — implements all seven steps, with COPY gated on `REDSHIFT_WORKGROUP` env-var presence so you can demo the S3-only path first and add Redshift later.

### Architecture

```
                  ┌──────────────────────────────────────────────────────┐
                  │             Lambda: csv_to_parquet_curated           │
                  │                                                      │
[S3 raw bucket]──▶│  1. Read CSV     ──▶  2. Validate schema             │
   PUT event      │  3. CSV → Parquet  ──▶  4. Write to partition prefix │──▶ [S3 curated]
                  │  5. CreatePartition (Glue Catalog)                   │──▶ [Glue Catalog]
                  │  6. ExecuteStatement (redshift-data) ── COPY          │──▶ [Redshift]
                  │  7. PutObjectTagging (idempotency mark)              │
                  └──────────────────────────────────────────────────────┘
                                  │
                                  ▼ (errors)
                          [Async DLQ — SQS]
```

### Setup

Same pattern as Use Case 2 (S3 → Lambda direct) for the trigger; the function body is where everything changes.

#### Step 1 — Curated table definition (one-time, instructor or first student)

The Glue table has to exist before `CreatePartition` succeeds. Run once via Athena (as your IAM user, in the cohort's workgroup):

```sql
CREATE EXTERNAL TABLE quicklabs_<USER_>_lake.oil_curated (
  trade_date  date,
  symbol      string,
  region      string,
  price       double,
  volume      bigint
)
PARTITIONED BY (year int, month int, day int)
STORED AS PARQUET
LOCATION 's3://quicklabs-<USER>-curated/oil_curated/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');
```

(`<USER_>` = your username with hyphens replaced by underscores.)

#### Step 2 — Add the AWS-managed pandas Lambda Layer

The handler uses pandas + pyarrow. Don't bundle them yourself (~70MB) — use the AWS-published "AWS SDK for pandas" managed layer. ARN format:

```
arn:aws:lambda:us-west-2:336392948345:layer:AWSSDKPandas-Python312:<version>
```

Pick the latest `<version>` for your region from the layer's docs.

#### Step 3 — Create the function

- Name: `quicklabs-<USER>-csv-to-parquet`
- Runtime: Python 3.12, `arm64`
- Memory: **1024 MB** (pandas is memory-hungry on parse + Parquet write)
- Timeout: **5 min** (CSV → Parquet for ~1 GB CSV takes 1–2 min)
- Execution role: `quicklabs-<USER>-lambda-role` (it already has the Glue + redshift-data perms after re-applying terraform-iam)
- Layer: the AWSSDKPandas layer from step 2
- Handler: `csv_to_parquet_curated.handler`
- Environment variables:
  - `CURATED_BUCKET = quicklabs-<USER>-curated`
  - `GLUE_DATABASE  = quicklabs_<USER_>_lake`
  - `TARGET_TABLE   = oil_curated`
  - (Leave `REDSHIFT_*` unset for the S3-only flow. Add them when you wire Redshift in step 5.)

#### Step 4 — S3 trigger

Bucket: `quicklabs-<USER>-raw`. Prefix: `oil_drop/`. Suffix: `.csv`. PUT events.

#### Step 5 — Smoke test (S3-only path)

```bash
USER=alice
cat > /tmp/oil-2025-05-12.csv <<EOF
trade_date,symbol,region,price,volume
2025-05-12,WTI,US,78.12,15000
2025-05-12,BRENT,EU,82.34,12400
2025-05-11,WTI,US,77.89,14100
EOF
aws s3 cp /tmp/oil-2025-05-12.csv s3://quicklabs-${USER}-raw/oil_drop/oil-2025-05-12.csv
```

Within ~10 seconds, verify:

```bash
# Parquet landed in the curated bucket, partitioned by date
aws s3 ls s3://quicklabs-${USER}-curated/oil_curated/ --recursive

# Glue catalog has the new partitions
aws glue get-partitions \
  --database-name quicklabs_${USER//-/_}_lake \
  --table-name oil_curated \
  --query 'Partitions[].Values'

# Athena can query the new partition (without any Glue crawler ever running)
aws athena start-query-execution \
  --work-group quicklabs-${USER}-wg \
  --query-string "SELECT * FROM quicklabs_${USER//-/_}_lake.oil_curated WHERE year=2025 AND month=5 AND day=12"
```

#### Step 6 — Wire Redshift (optional, instructor-provisioned)

The instructor will hand you the Redshift Serverless workgroup name + a copy role ARN that Redshift uses to read your curated bucket. Add these to your Lambda env vars:

- `REDSHIFT_WORKGROUP = <cohort-shared-workgroup>`
- `REDSHIFT_DATABASE  = dev`
- `REDSHIFT_COPY_ROLE_ARN = arn:aws:iam::ACCT:role/cohort-redshift-copy`

Re-trigger the Lambda (upload another CSV). The function now also submits a COPY statement. Verify:

```bash
# List recent Redshift Data API statements
aws redshift-data list-statements --max-results 5

# Describe the most recent one — look for Status=FINISHED
aws redshift-data describe-statement --id <statement-id-from-above>

# Query Redshift to confirm rows loaded
aws redshift-data execute-statement \
  --workgroup-name <workgroup> \
  --database dev \
  --sql "SELECT COUNT(*) FROM oil_curated WHERE year=2025 AND month=5 AND day=12"
```

### When this works, when you should reach for Spark

Lambda-as-ETL is a deliberate choice with a real envelope. Past the envelope, you need Glue/Spark even if politics say otherwise.

| Volume per file | Partitions per file | Lambda fits? | Why |
|---|---|---|---|
| < 200 MB | < 5 | ✅ Comfortable | Plenty of headroom on 10 GB Lambda memory and 15 min timeout |
| 200 MB – 1 GB | < 20 | ⚠️ Tune memory + timeout | Allocate 4–10 GB memory; the timeout cap is the real risk |
| 1–5 GB | < 50 | ⚠️ Splittable only | Pre-split source files in the producer or in a fronting "splitter" Lambda |
| > 5 GB | any | ❌ Spark territory | Lambda's 10 GB memory + 15 min timeout makes this brittle. Glue / EMR Serverless or Redshift COPY direct from raw via UDF |
| any | > 100 | ❌ Spark territory | Per-partition write + register is sequential; Glue Spark parallelises both |

### Idempotency, retries, and the DLQ

The handler is idempotent by design — on retry, `_already_processed` short-circuits before any I/O. But there are still failure modes worth knowing:

| Failure | What happens | What to do |
|---|---|---|
| Schema mismatch in source | Handler raises `ValueError`, Lambda retries twice, then async-DLQ | Fix the source contract, drain the DLQ manually |
| Glue `CreatePartition` race (two files for same partition at the same time) | Handler catches `AlreadyExistsException`, continues | Nothing — by design |
| Redshift COPY fails (bad credentials, schema drift) | The S3 + catalog side succeeded; only the COPY step is dropped | Re-run COPY from Redshift Query Editor; Lambda doesn't retry COPY |
| Timeout mid-write | Partial Parquet in S3 — partition entry may or may not exist | Manually `aws s3 rm` the partial file; rerun by removing the `ingest-status` tag on the source |

### What you can NOT do without Glue

Knowing the limits keeps the architecture honest:

- **Schema-on-read** — you have to declare schemas in code. Welcome to typed pipelines.
- **Automatic partition discovery** — every partition must be registered explicitly. Don't write to a path you haven't catalogued; Spectrum just won't see it.
- **Compaction** — small files accumulate (one per Lambda invocation). After 24h you'll have hundreds of tiny Parquet files per partition. Run a periodic **Athena CTAS** or a Lambda-driven compaction job to fold them back into 128 MB – 1 GB sizes. Without this, query performance degrades over time.
- **Cross-source joins at ingest** — anything that needs to join two source streams during transform is out of Lambda's comfort zone; reach for Step Functions + Redshift staging tables.

---

## SQS vs. Kinesis — when to reach for streaming

Both deliver messages to consumers. Pick by **what you need from the ordering and retention story**, not by throughput:

| Need | Pick |
|---|---|
| Ordered processing across millions of events per second, with replay capability | **Kinesis** |
| At-least-once delivery, per-message ack, simple fan-out, DLQ on poison messages | **SQS** |
| Stream analytics (sliding windows, joins) inline with the pipeline | **Kinesis** + Kinesis Analytics / Flink |
| Cohort-friendly cost profile, no shard math, no retention sizing | **SQS** |
| Multiple independent consumers reading the same events at their own pace | **Kinesis** (or SNS + SQS fan-out) |

For both use cases in this lab, **SQS is right** — the consumer is a single Lambda function, ordering doesn't matter (each S3 object is independent), and we want per-message retry + DLQ. Kinesis would force us to think about shard count and consumer checkpointing for no payoff.

---

## Design considerations — things to internalize before shipping

- **Visibility timeout >> Lambda timeout.** AWS recommends 6×. If Lambda runs longer than the visibility timeout, SQS thinks the message failed and redelivers it — your handler runs twice on the same payload.
- **Idempotency.** S3 → SQS → Lambda is at-least-once. Either make the handler idempotent (the `batch_file_handler` tags the source object with `ingest-status=processed` for this reason) or dedupe by `messageId`.
- **`batchItemFailures` matters.** Without it, a single bad message in a batch of 10 makes Lambda retry the whole batch — and the 9 good messages get processed twice.
- **Metadata sidecars.** Many field-capture pipelines pair a binary (`tank-1.jpg`) with a JSON metadata file (`tank-1.json`). Decide upfront: **fail closed** (wait for sidecar before processing) or **fail open** (process binary, attach sidecar later if it arrives). The sample handler is fail-open.
- **ITAR / sensitive data.** Tag the raw bucket and any queue carrying sensitive references with a `data-classification` tag. Don't log payload contents. Consider SSE-KMS over SSE-S3 so access leaves a CloudTrail trail on the key. Restrict the curated bucket policy to the Lambda role only.
- **Cold-start latency.** For field-imagery flows where end-to-end latency matters, set Lambda's **provisioned concurrency = 1** during business hours. Adds cost; removes the ~600ms cold-start tax on the first event of the day.
- **Cost shape.** Lambda + SQS scales to zero. Kinesis charges per shard-hour 24/7 regardless of traffic. For sub-100-events/second, SQS will be 10–100× cheaper.

---

## Enterprise context — Field data collection at scale

Field crews collect imagery and sensor readings on internal-network devices. They batch-upload to S3 at end-of-shift. The same architecture maps directly:

| Lab piece | Enterprise mapping |
|---|---|
| Raw S3 bucket | Per-site landing zone, KMS-encrypted, VPC endpoint only |
| SQS queue | One queue per site or per data-classification level |
| Lambda → curated | Validation + metadata extraction + routing to the analytics warehouse + the operator UI |
| DLQ | Triaged by the field-data ops team; messages here block sign-off on a shift's data |
| Sidecar JSON | Carries ITAR markings + export-control flags — drives downstream routing |

The patterns are the same; what changes is the encryption posture (CMK per data classification), the network posture (VPC endpoints, no public S3), and the audit posture (CloudTrail data events on the raw bucket).

---

## Knowledge check

1. You set Lambda's timeout to 60 seconds. What's the minimum SQS visibility timeout you should configure on the source queue, and why?
2. A single bad image causes your handler to throw. With `batchItemFailures` reporting enabled, what happens to the other 9 messages in the same batch? What happens without it?
3. Why does the handler use `s3:CopyObject` (use case 2) rather than `get_object` + `put_object`?
4. You're choosing between S3 → SQS → Lambda and S3 → Lambda direct for a partner-SFTP drop that produces ~50 files/day on a fixed schedule. Which do you pick, and what's the one-sentence justification you'd give in design review?
5. The DLQ is filling up with messages whose payload is a `RequestTimeout` from S3. Is this a code bug, a config bug, or both?
6. Which of these belongs in the Lambda *execution role* vs. the *student IAM user* policy, and why?
   - `sqs:ReceiveMessage` on the image queue
   - `lambda:CreateFunction`
   - `iam:PassRole` for the Lambda role
   - `s3:GetObject` on the raw bucket

Answers in `student-lambda-lab-answers.md` (instructor-provided).
