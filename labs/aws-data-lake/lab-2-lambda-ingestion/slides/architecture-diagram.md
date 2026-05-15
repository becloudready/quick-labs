# Event-driven ingestion architecture — S3 as the landing zone

One overview diagram covering all three use cases from `student-lambda-lab.md`. Use this on the opening slide of Module 4 / Lab 2 so students can return to it as you walk each pattern.

---
---

## Mermaid version (renders inline on GitHub / GitLab / many wikis)

```mermaid
flowchart LR
    %% Producers
    Devices[Field devices]
    Cron[Batch scheduler]
    Partner[Partner SFTP]
    OpDB[(Operational DB)]

    %% Landing
    subgraph Landing["S3 LANDING ZONE — quicklabs-&lt;u&gt;-raw<br/>(SSE-KMS, VPC endpoint, versioning)"]
        Raw_Images[images/]
        Raw_Drop[drop/]
        Raw_Oil[oil_drop/]
    end

    Devices -->|PUT .jpg + sidecar| Raw_Images
    Cron -->|PUT .csv| Raw_Drop
    Partner -->|PUT .csv| Raw_Oil
    OpDB -.->|DMS / CDC<br/>out of scope| Landing

    %% Use Case 1 — SQS-fronted
    subgraph UC1["Use Case 1 — SQS-front (async fan-in)"]
        SQS_Events[SQS<br/>image-events]
        Lambda_Image[Lambda<br/>image_metadata_handler]
        DLQ_Image[DLQ<br/>image-dlq]
    end
    Raw_Images -->|S3 event| SQS_Events
    SQS_Events --> Lambda_Image
    Lambda_Image -.->|poison<br/>maxReceiveCount=5| DLQ_Image

    %% Use Case 2 — direct
    subgraph UC2["Use Case 2 — S3 direct (batch drop)"]
        Lambda_Batch[Lambda<br/>batch_file_handler]
        DLQ_Async[Async DLQ<br/>SQS]
    end
    Raw_Drop -->|S3 event| Lambda_Batch
    Lambda_Batch -.->|async invoke<br/>fails after retries| DLQ_Async

    %% Use Case 3 — Lambda-as-ETL
    subgraph UC3["Use Case 3 — Lambda-as-ETL (Redshift + S3 lakehouse)"]
        Lambda_ETL[Lambda<br/>csv_to_parquet_curated]
        GlueCat[Glue Data Catalog<br/>passive metadata]
        Redshift[(Redshift Serverless)]
    end
    Raw_Oil -->|S3 event| Lambda_ETL
    Lambda_ETL -->|CreatePartition| GlueCat
    Lambda_ETL -->|redshift-data:<br/>ExecuteStatement COPY| Redshift

    %% Curated
    subgraph Curated["S3 CURATED — quicklabs-&lt;u&gt;-curated"]
        Cur_Meta[image-metadata/]
        Cur_Batch[batch/yyyy/mm/dd/]
        Cur_Oil[oil_curated/year=Y/<br/>month=M/day=D/]
    end
    Lambda_Image --> Cur_Meta
    Lambda_Batch --> Cur_Batch
    Lambda_ETL --> Cur_Oil

    %% Query layer
    subgraph Query["Query / analytics"]
        Athena[Athena<br/>workgroup]
        Spectrum[Redshift Spectrum<br/>external schema]
    end
    GlueCat --> Athena
    GlueCat --> Spectrum
    Cur_Oil -.->|via external schema| Spectrum

    %% Observability
    subgraph Observ["Cross-cutting observability"]
        CW[CloudWatch<br/>Logs + Metrics + Alarms]
        CT[CloudTrail<br/>data events]
    end
    Lambda_Image -.-> CW
    Lambda_Batch -.-> CW
    Lambda_ETL -.-> CW
    Landing -.-> CT
    Curated -.-> CT
```

---

## Per-use-case sequence diagrams (Mermaid)

### Use Case 1 — SQS-fronted fan-in

```mermaid
sequenceDiagram
    autonumber
    participant Device
    participant S3raw as S3 raw
    participant SQS
    participant Lambda as Lambda (image_metadata_handler)
    participant S3cur as S3 curated
    participant DLQ

    Device->>S3raw: PUT images/tank-1.jpg + .json sidecar
    S3raw->>SQS: ObjectCreated event
    SQS->>Lambda: poll batch (size 10, window 5s)
    Lambda->>S3raw: GetObject head + sidecar
    Lambda->>S3cur: PutObject image-metadata/...json
    Lambda-->>SQS: success → DeleteMessage
    Note over Lambda,DLQ: on repeated failure (maxReceiveCount=5)
    Lambda--xDLQ: message moved by SQS
```

### Use Case 2 — direct invoke

```mermaid
sequenceDiagram
    autonumber
    participant Cron
    participant S3raw as S3 raw
    participant Lambda as Lambda (batch_file_handler)
    participant S3cur as S3 curated
    participant AsyncDLQ as Lambda async DLQ

    Cron->>S3raw: PUT drop/sales-2025-09-12.csv
    S3raw->>Lambda: async invoke (ObjectCreated)
    Lambda->>S3raw: CopyObject → curated path
    Lambda->>S3raw: PutObjectTagging ingest-status=processed
    Note over Lambda,AsyncDLQ: 2 retries on failure
    Lambda--xAsyncDLQ: poison event after retries
```

### Use Case 3 — Lambda-as-ETL

```mermaid
sequenceDiagram
    autonumber
    participant Partner
    participant S3raw as S3 raw
    participant Lambda as Lambda (csv_to_parquet_curated)
    participant S3cur as S3 curated
    participant Glue as Glue Catalog
    participant Redshift

    Partner->>S3raw: PUT oil_drop/oil-2025-05-12.csv
    S3raw->>Lambda: async invoke
    Lambda->>S3raw: GetObject (CSV)
    Note right of Lambda: validate schema<br/>transform → Parquet<br/>group by trade_date
    Lambda->>S3cur: PutObject oil_curated/year=.../month=.../day=.../...parquet
    Lambda->>Glue: CreatePartition (Hive-style values)
    Lambda->>Redshift: redshift-data ExecuteStatement<br/>COPY ... FROM '...' FORMAT PARQUET
    Lambda->>S3raw: PutObjectTagging ingest-status=processed
```



