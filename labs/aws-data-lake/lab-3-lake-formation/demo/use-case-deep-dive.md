# Use case — "Central data lake with federated consumers" (L300 deep dive)

Anchors a 60–90 minute walk-through inside Module 5 + Module 6. Use it as the spine of the morning session: introduce the scenario on slide 2, return to it on every concept slide ("…and here's how that piece works in our scenario"), and close with the cross-account section on slides 17 and 36.

The use case is intentionally industry-neutral so the same script works for any audience. Substitute the producer / consumer business-unit names for whatever fits the room.

---

## Setting

**Org shape:** one **Central Data Platform** AWS account that owns the canonical data lake. Two **business unit** consumer accounts (call them **Finance** and **Operations**) that need read access to subsets of the lake. A handful of personas inside each consumer account.

**Why this is the canonical L300 shape:** every Lake Formation production deployment AWS publishes blog posts about reduces to this. Producer owns storage + catalog; consumers query through their own credentials; LF is the seam where governance happens. Once students see this shape, every later integration (Spectrum, EMR, Glue jobs) is a footnote.

```
┌─────────────────────────────────────────────────┐    ┌────────────────────────┐
│ Central Data Platform account                   │    │ Finance account        │
│                                                 │    │                        │
│  s3://central-raw/        s3://central-curated/ │    │  Athena workgroup      │
│       │                          │              │    │  ↑                     │
│       └──Glue crawler────────────┘              │    │  resource links        │
│                  │                              │    │  (fin_db.payments → …) │
│                  ▼                              │    │                        │
│        Glue Data Catalog                        │    │  finance-analyst-role  │
│                  ▲                              │    │  finance-engineer-role │
│                  │                              │    └────────────────────────┘
│        Lake Formation                           │                ▲
│        ── LF-Tags (taxonomy)                    │                │
│        ── Row + column filters                  │   AWS RAM share (auto-created
│        ── Cross-account grants                  │    by LF GrantPermissions)
│        ── Audit → CloudTrail                    │                │
│                  │                              │                ▼
│                  └──────────────────────────────┼──→  ┌────────────────────────┐
│                                                 │    │ Operations account     │
└─────────────────────────────────────────────────┘    │                        │
                                                       │  ops-engineer-role     │
                                                       │  ops-analyst-role      │
                                                       └────────────────────────┘
```

---

## Tag taxonomy (this is the spine — write it on the whiteboard first)

Three tag dimensions cover every grant the org ever writes:

| Tag key | Values | Who applies it | What it controls |
|---|---|---|---|
| `classification` | `public`, `internal`, `restricted` | Data steward at ingestion | What level of sensitivity the data carries |
| `layer` | `raw`, `enriched`, `consolidated` | Set by the pipeline stage that wrote the table | Curation maturity |
| `business_unit` | `finance`, `operations`, `marketing`, `shared` | Producer team during onboarding | Which consumer accounts even see the table |

The grant rule is then **one line per persona, ever:**

| Persona | Tag expression |
|---|---|
| Central data engineer | any classification × any layer × any BU |
| Finance analyst | `classification ∈ {public, internal}` AND `layer = consolidated` AND `business_unit ∈ {finance, shared}` |
| Finance engineer | any classification × any layer × `business_unit ∈ {finance, shared}` |
| Operations analyst | `classification ∈ {public, internal}` AND `layer = consolidated` AND `business_unit ∈ {operations, shared}` |

When a new dataset lands, the steward tags it once. No new grants needed for any consumer.

**Why this is the magic.** Per-table grants don't scale — at 50 tables × 4 personas × 2 consumer accounts you're at 400 grants, and every new table multiplies. Tag-based grants are O(personas), independent of table count.

---

## The data the demo uses

Reuse what Lab 1 already produced. Each student already has:

- `quicklabs_<USER_>_lake.oil` — curated oil-price table, partitioned by year

For the multi-account part of the demo, augment with two synthetic tables under the same database (instructor pre-creates these once for the cohort, students share read-only):

- `payments` — invoice records (columns: `invoice_id`, `customer_id`, `amount`, `region`, `processed_at`, `internal_note`) — tagged `business_unit = finance`, `classification = restricted`
- `shipments` — logistics events (`shipment_id`, `origin`, `destination`, `weight_kg`, `dispatched_at`) — tagged `business_unit = operations`, `classification = internal`

That gives you three datasets representing the three BU tags.

---

## Demo runbook (60 minutes)

### Act 1 — The naive grant (10 min)

Open the LF console as the central data lake admin. Show the Finance analyst trying to query `payments`. They get `AccessDeniedException` because LF is enforcing and no grant exists.

The instinct: `GRANT SELECT ON TABLE payments TO 'arn:…role/finance-analyst'`. Do it, query succeeds. Then ask the room: "What happens when we add `invoices`, `refunds`, `chargebacks`?" — point at the room math (4 personas × 3 tables × 2 consumer accounts = 24 grants).

Revoke the table grant. Set the stage for tags.

### Act 2 — Tag the world once (15 min)

In the central account:

1. Define the three LF-Tags + their value sets (the taxonomy table above).
2. Attach tags to the central database (`business_unit=shared, classification=public` — applies to everything inside unless overridden).
3. Override on individual tables:
   - `payments` → `business_unit=finance, classification=restricted`
   - `shipments` → `business_unit=operations, classification=internal`
   - `oil` → leave the database-level tags (i.e., shared + public)
4. **Column override** on `payments.internal_note` → `classification=restricted` (already inherited, but show that column tags exist).

Now write the grants — **once, per persona:**

```sql
-- Finance analyst: consolidated layer, non-restricted, finance or shared
GRANT SELECT ON TABLES WITH LF_TAG_EXPRESSION (
  classification IN ('public', 'internal')
  AND layer = 'consolidated'
  AND business_unit IN ('finance', 'shared')
) TO ROLE 'arn:aws:iam::<finance-acct>:role/finance-analyst';
```

Re-query as the Finance analyst → `payments` is denied (classification=restricted), `oil` succeeds (shared/public/consolidated).

**The aha moment:** add a brand new table `expenses` tagged `business_unit=finance, classification=internal, layer=consolidated`. No new grant. Finance analyst can query it immediately. Operations analyst can't. This is the slide where students lean forward.

### Act 3 — Row + column filters within a tag-granted table (10 min)

Tag-based grants are coarse. Inside a granted table you may need to mask columns or filter rows by attribute. The data cells filter Lab 3 already provisioned (`year >= 2020`, exclude `price`) is exactly this — but now the framing is "this composes ON TOP OF the tag grant."

Show the precedence on slide 13:

1. Explicit table-level grants for the principal (most specific) — beats…
2. Tag expression grants (broad) — beats…
3. Database-level grants (rare in this model) — beats…
4. IAMAllowedPrincipals legacy default (revoked in our account).

Run a query as the analyst. Show the LF console → Data filters → highlight the active filter on `oil` is making the result narrower than the tag grant would alone.

### Act 4 — Cross-account share (15 min)

This is the part most cohorts haven't seen and is the highest-value 15 minutes of Day 2.

In the central account:

```sql
GRANT SELECT ON TABLES WITH LF_TAG_EXPRESSION (
  classification IN ('public', 'internal')
  AND business_unit IN ('finance', 'shared')
) TO 'arn:aws:iam::<finance-acct>:role/finance-analyst';
```

Notice the principal is a role ARN in a **different account**. Behind the scenes Lake Formation:

1. Auto-creates an AWS RAM resource share for the impacted databases/tables.
2. Sends an invitation to the consumer account (auto-accepted if both accounts are in the same AWS Organization).
3. The consumer account's LF admin sees the resources appear under "Shared with me".

In the consumer account, show:

1. The AWS RAM console → Resource shares → the auto-created share, the principal it was sent to.
2. The LF console → Data catalog → Tables → the producer's tables are visible but addressed by ARN.
3. Create a **resource link** in the consumer's own catalog: `fin_db.payments → central_db.payments`. Resource links are the consumer-side abstraction that makes Athena queries work with the usual `database.table` syntax.
4. As `finance-analyst` in the consumer account, query `SELECT * FROM fin_db.payments LIMIT 5` — it works, and respects all filters set in the producer.

**Critical "gotcha" worth pausing on:** the producer's KMS keys (if the data is SSE-KMS encrypted) need a key policy that grants `kms:Decrypt` to the consumer principal. LF cross-account share does not auto-update KMS key policies. Most "it works in dev, fails in prod" incidents are this.

### Act 5 — The audit trail (10 min)

Open CloudTrail in the central account. Filter on `eventSource = lakeformation.amazonaws.com`. Show three event names:

- `GrantPermissions` / `RevokePermissions` — who granted what to whom and when. This is the auditor's first stop.
- `GetDataAccess` — **every** authorized read. Includes the principal ARN, the table/columns, and the filter ID applied. Correlates one-to-one with the Athena `queryId`.
- `CreateLFTag` / `AddLFTagsToResource` — taxonomy changes (rare, high-stakes — alert on these).

Pull one `GetDataAccess` event. Walk the structure: `userIdentity` (who), `requestParameters.tableArn` (what), `responseElements.authorizedSessionTagValueArray` (the tags that authorized it). Show how an auditor reconstructs "did the finance analyst ever see restricted data" with a single Athena query over the CloudTrail logs.

This is the slide that closes the deal with security and compliance stakeholders.

---

## Mapping to the existing terraform-lab/lab-3-lake-formation/ module

The current module sets up the **single-account** version of this (LF-Tags, one filter, one analyst role). To extend it for the L300 demo, add — in order:

1. **Two more tables in the curated bucket.** Synthesize `payments.csv` and `shipments.csv`, upload to `s3://quicklabs-<u>-curated/payments/` and `…/shipments/`, run the curated crawler so the catalog picks them up.

2. **Two more values per tag dimension.** Extend the `classification` and `business_unit` tag definitions in `main.tf` so the grant matrix in this doc can be expressed.

3. **Tag attachment overrides.** Add `aws_lakeformation_resource_lf_tags` blocks for each new table (database-level tags inherit; only attach overrides where the table differs).

4. **Two new IAM roles per student** representing Finance vs. Operations personas (siblings of the existing `data-analyst-role`). Add them to `terraform-iam/`, mirror the trust policy pattern.

5. **Three `aws_lakeformation_permissions` blocks** — one tag-expression grant per persona, exactly as shown in Act 2.

6. **(Optional, instructor-only) Cross-account stub.** Adding a second AWS account during a 6.5h course is wasteful — instead, point at a pre-recorded screencast of the cross-account flow from instructor's earlier setup, or use a "dummy" sub-account (Organizations sub-account) the instructor already has wired.

For Lab 3 as it exists, **steps 1–5 are realistic in-class extensions**; step 6 belongs in a follow-up workshop.

---

## What students walk out knowing

- **The grant explosion problem and the tag solution.** They can recite "per-table grants don't scale; tag-based grants are O(personas)."
- **The producer/consumer mental model.** Central catalog owns the source of truth; consumer accounts hold compute + resource links.
- **The four-layer precedence stack.** Table → Tag → Database → IAMAllowedPrincipals.
- **Where the audit trail lives.** CloudTrail `GetDataAccess`, queryable from Athena.
- **The three things that break in production**, in priority order:
  1. KMS key policy not updated for cross-account decrypt
  2. IAMAllowedPrincipals not revoked → LF silently not enforcing
  3. Resource link not created in consumer → Athena `database.table` lookup fails

---

## References

- AWS Whitepaper — *AWS Lake Formation: How it Works* (architecture vocabulary used above)
- AWS Documentation — *Cross-account data sharing in Lake Formation* (the RAM + resource link mechanics in Act 4)
- AWS Documentation — *Tag-based access control in Lake Formation* (the grant syntax in Act 2)
- AWS Well-Architected Data Analytics Lens — DATA-LAKE-2 ("How do you catalog and govern data?") maps to the entire taxonomy section
- AWS Skill Builder — *Lake Formation Workshop* (workshops.aws) has the cross-account share as a hands-on if you want to convert step 6 to a real lab later
