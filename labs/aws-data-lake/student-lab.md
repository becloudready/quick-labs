# AWS Data Lake — Student Lab

You'll build an end-to-end data pipeline on AWS:

```
S3 raw CSV  →  Glue Crawler  →  Glue Catalog  →  Glue ETL Job  →  S3 curated Parquet  →  Glue Crawler  →  Athena
```

The infrastructure (buckets, IAM, Glue role, ETL job, crawlers, Athena workgroup) is already provisioned in your sandbox. Your job is to **run the pipeline, query the data, and then point it at a different dataset**.

Time: ~90 minutes including the assignment.

---

## What your instructor gave you

| | Value |
|---|---|
| Console URL | `https://<ACCOUNT_ID>.signin.aws.amazon.com/console` |
| Username | `quicklabs-<YOUR_NAME>` |
| Password | (one-time, change on first login) |
| Region | **us-west-2 (Oregon)** — anything else is denied |

Throughout this doc, replace `<USER>` with your username (e.g. `suresh`). Your resources are all named with that prefix.

| Resource | Name |
|---|---|
| Raw bucket | `quicklabs-<USER>-raw` |
| Curated bucket | `quicklabs-<USER>-curated` |
| Scripts bucket | `quicklabs-<USER>-scripts` |
| Athena results bucket | `quicklabs-<USER>-athena-results` |
| Glue database | `quicklabs_<USER>_lake` (note underscores) |
| Raw crawler | `quicklabs-<USER>-raw-crawler` |
| ETL job | `quicklabs-<USER>-oil-etl` |
| Curated crawler | `quicklabs-<USER>-curated-crawler` |
| Athena workgroup | `quicklabs-<USER>-wg` |

---

## Step 0 — Sign in & set the region

1. Open the console URL above in an **incognito/private browser window** (so it doesn't conflict with other AWS sessions).
2. Sign in with your username and one-time password. Set a new password when prompted.
3. **Top-right region picker → Oregon (us-west-2).** Your policy denies every other region — if you forget this step, every page will look broken.
4. Sanity check: top-right shows `quicklabs-<USER> @ <ACCOUNT_ID>` and region is `Oregon`.

---

## Step 1 — Look around (no clicks change anything)

Spend 5 minutes opening these and confirming you can see your resources:

- **S3** → 4 buckets starting with `quicklabs-<USER>-`. Open `quicklabs-<USER>-raw/oil/` and confirm `Crude_Oil_historical_data.csv` is there.
- **AWS Glue** → Data Catalog → Databases → you'll see `quicklabs_<USER>_lake` (and other students' databases — you can read them but not modify).
- **AWS Glue** → Crawlers → you'll see your `raw-crawler` and `curated-crawler`. State should be `Ready`.
- **AWS Glue** → ETL jobs → you'll see `quicklabs-<USER>-oil-etl`. Click it → Script tab → read the PySpark code (~80 lines). Don't run it yet.
- **Athena** → Workgroups → switch to `quicklabs-<USER>-wg` (top-left dropdown). The default `primary` is denied for you.

If anything is missing or denied, **stop and ask the instructor** — likely a region issue or a policy gap.

---

## Step 2 — Run the raw crawler (CSV → catalog table)

The crawler reads the CSV file in `quicklabs-<USER>-raw/oil/` and creates a table in the Glue catalog so Athena can query it.

1. Glue → Crawlers → click `quicklabs-<USER>-raw-crawler` → **Run**.
2. Wait ~1–2 min. Status goes `Starting` → `Running` → `Stopping` → `Ready`.
3. Glue → Databases → `quicklabs_<USER>_lake` → Tables → you'll see a new table `raw_oil` (the `raw_` prefix comes from the crawler config).
4. Click `raw_oil` → check the schema. You should see 8 columns: `date, open, high, low, close, volume, ticker, name`.

**What just happened:** Glue scanned the CSV, inferred the schema, and registered metadata in the catalog. The CSV file itself didn't move.

---

## Step 3 — Query the raw table from Athena

1. Athena → Editor. Confirm the workgroup dropdown (top-left) shows `quicklabs-<USER>-wg`.
2. In the database dropdown (left panel), pick `quicklabs_<USER>_lake`.
3. Run:

   ```sql
   SELECT COUNT(*) FROM raw_oil;
   ```

   Expect **6367**.

4. Try a few more:

   ```sql
   SELECT * FROM raw_oil LIMIT 10;

   SELECT MIN(date), MAX(date) FROM raw_oil;
   ```

You're now querying CSV-on-S3 with no servers. Note Athena tells you the data scanned per query — that's what you pay for.

---

## Step 4 — Run the ETL job (CSV → Parquet)

The CSV format is fine for ad-hoc but slow and expensive at scale. The ETL job converts it to Parquet (columnar, compressed) partitioned by year, which makes queries 10–100× faster.

1. Glue → ETL jobs → click `quicklabs-<USER>-oil-etl` → **Run**.
2. Click "Runs" tab → watch the job. Cold start is ~1–2 min, then runs ~1 min.
3. When it shows `Succeeded`, look at the Output logs (CloudWatch link) — you'll see the script's print statements showing rows in/rows out.
4. S3 → `quicklabs-<USER>-curated/oil/` → you'll see folders `year=2000/`, `year=2001/`, ... `year=2025/`. Each contains one `.snappy.parquet` file.

**What just happened:** Spark read the CSV, parsed the timezone-aware date, derived `year`/`month`/`daily_range`/`daily_change_pct`, dropped null rows, wrote Parquet partitioned by year. Open the script in the job editor to follow each transformation.

---

## Step 5 — Crawl the curated zone & query Parquet

1. Glue → Crawlers → `quicklabs-<USER>-curated-crawler` → **Run**. Wait for `Ready`.
2. Glue → Databases → `quicklabs_<USER>_lake` → Tables → you now have `curated_oil` (Parquet) alongside `raw_oil` (CSV).
3. In Athena:

   ```sql
   SELECT year,
          COUNT(*)             AS days,
          ROUND(AVG(close), 2) AS avg_close,
          ROUND(MAX(high), 2)  AS yr_high,
          ROUND(MIN(low), 2)   AS yr_low
   FROM curated_oil
   GROUP BY year
   ORDER BY year;
   ```

   Expect 26 rows: per-year summary of crude oil futures from 2000 to 2025.

4. **Compare** — run the same query against `raw_oil` and look at the "Data scanned" stat for each. The Parquet version scans ~10× less. That difference compounds at TB scale.

The pipeline is closed. Everything from raw CSV to analytics query is working end-to-end.

---

## Assignment — bring your own dataset

Pick a dataset from [Kaggle](https://www.kaggle.com/datasets) (CSV format, anything that interests you — stocks, weather, sports, etc.) and run it through the same pipeline.

Suggested flow:

1. **Get the data.** Download from Kaggle. Aim for < 100 MB to keep the lab fast.
2. **Upload to your raw bucket** under a new prefix:
   ```
   s3://quicklabs-<USER>-raw/<your-dataset-name>/file.csv
   ```
   Use the S3 console (Upload button) or CLI (`aws s3 cp`).
3. **Crawl it.** Glue → Crawlers → Create crawler:
   - Name: `quicklabs-<USER>-<dataset>-crawler`
   - Data source: `s3://quicklabs-<USER>-raw/<your-dataset-name>/`
   - IAM role: pick the existing `quicklabs-<USER>-glue-role`
   - Database: `quicklabs_<USER>_lake`
   - Table prefix: `raw_`
   - Run it → check the new table appears.
4. **Query it in Athena.** Try `SELECT * LIMIT 10`, `COUNT(*)`, basic aggregations.
5. **(Stretch) Write your own ETL job.** Either:
   - Modify `oil_csv_to_parquet.py` (in `s3://quicklabs-<USER>-scripts/`) to fit your dataset's schema, OR
   - Write a fresh PySpark script. Upload it. Create a new Glue job pointing at it. Same role, same Glue 4.0, G.1X × 2.
6. **Crawl the curated output and query the Parquet.** Compare data scanned vs the raw CSV.

What you're really learning here: the **shape of every data lake project** — land raw, catalog, transform, catalog again, query. The dataset is just the variable.

---

## Things you might hit

| Symptom | Likely cause |
|---|---|
| "Access denied" on a Glue / S3 / Athena page | Region isn't us-west-2 |
| Crawler finishes but no table appears | Wrong S3 path, or path empty |
| ETL job fails with `AnalysisException: Cannot resolve column ...` | Your script references a column that doesn't exist after a transform — check the schema you're projecting |
| ETL job fails with `AccessDenied` to S3 | The Glue role only has access to `quicklabs-<USER>-*` buckets — make sure you're reading/writing your own |
| Athena query "Insufficient permissions" | Switch the workgroup dropdown to `quicklabs-<USER>-wg` |
| Athena query times out / scans huge data | You're querying the raw CSV, not the Parquet — switch the table |

---

## When to ask the instructor

- Anything denied that you think *should* work → it's a policy gap, the instructor will fix it once for everyone.
- Glue job stuck in `Running` for > 10 min → tell the instructor.
- You want to use a non-CSV format (JSON, Avro, fixed-width) → the instructor will help you adjust the crawler / script.
- Your dataset is huge (> 1 GB) → ask before uploading; we may need to scale up the worker count.

The whole point of the lab is the loop: **change something → run it → see what happened → ask why**. Don't read ahead — try the next step, see what breaks, then ask.
