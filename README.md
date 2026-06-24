# Accounting Data Pipeline

A containerized data pipeline that ingests raw ledger exports from a Polish
ERP system (modeled on Comarch Optima), cleans and transforms them with dbt,
and produces report-ready tables for PowerBI. Orchestrated with Apache Airflow,
running fully in Docker.

## What this project does

- Ingests semicolon-delimited CSV ledger exports (Polish ERP format)
- Loads raw data into PostgreSQL via a Python ingestion script
- Cleans, types, and standardizes the data in a dbt staging layer
- Produces three reporting marts: monthly P&L, accounts payable aging,
  and VAT summary
- Validates data integrity with dbt tests, including a custom
  double-entry balance check
- Runs on a schedule via Airflow, fully containerized with Docker Compose

## Architecture

```
CSV export → Python loader → raw.raw_ledger (Postgres)
                                    │
                                    ▼
                          dbt staging (stg_ledger)
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            mart_pl_by_period  mart_ap_aging  mart_vat_summary
                                    │
                                    ▼
                                Power BI 
```

Orchestrated end to end by an Airflow DAG: `run_loader` → `run_dbt_build`.

## Stack

| Layer             | Tool                          |
|-------------------|-------------------------------|
| Orchestration     | Apache Airflow (Docker)       |
| Transformation    | dbt Core + dbt-postgres       |
| Storage           | PostgreSQL (containerized)    |
| Ingestion         | Python (pandas, SQLAlchemy)   |
| Reporting         | Power BI                      |

## Project structure

```
accounting_pipeline/
├── dbt_project.yml
├── profiles.yml.example      # copy to profiles.yml, fill in real values
├── models/
│   ├── staging/
│   │   ├── stg_ledger.sql
│   │   └── sources.yml
│   └── marts/
│       ├── mart_pl_by_period.sql
│       ├── mart_accounts_payable.sql
│       ├── mart_vat_summary.sql
│       └── marts.yml
├── seeds/
│   └── chart_of_accounts.csv
├── tests/
│   ├── assert_double_entry_balance.sql
│   └── assert_vat_within_reasonable_bounds.sql
├──  loader.py
└──  data/
     └──raw_ledger_export_multimonth.csv

airflow-accounting-pipeline/
├── docker-compose.yaml
├── Dockerfile
├── .env.example               # copy to .env, fill in real values
└── dags/
    └── accounting_pipeline_dag.py
```

## Setup

1. Clone the repository
2. Copy the example config files and fill in real values:
   ```bash
   cp .env.example .env
   cp profiles.yml.example profiles.yml
   ```
3. Build and start the stack:
   ```bash
   docker compose up airflow-init
   docker compose up -d
   ```
4. Open the Airflow UI at `http://localhost:8080`
5. Place a ledger export CSV in the expected data folder and trigger the
   `accounting_pipeline` DAG, or run components individually for testing:
   ```bash
   docker compose exec airflow-worker bash -c \
     "cd /opt/airflow/accounting_pipeline && dbt build --profiles-dir /opt/airflow/accounting_pipeline"
   ```
6. For data visualization, connect PowerBI to the host-side port specified in .env.

## Data model notes

- Source ledger uses Polish double-entry convention: both debit and credit
  amounts are recorded as positive values, with direction indicated by
  separate account columns (`Konto_Wn` / `Konto_Ma`) rather than by sign.
- Analytical sub-accounts (e.g. `210-DOSTAWCA-001`) are resolved to their
  parent account code before joining to the chart of accounts. The account 
  numbers are purposefully labeled in a non-standard way, as proof of 
  the versatility of such pipelines.
- VAT clearing accounts (`222-1`, `223-1`) are excluded from P&L
  aggregation and reported separately in `mart_vat_summary`.

## Sample data

This repository does not include real business data. A synthetic sample
ledger export is provided for testing the pipeline end to end — see
`data/raw_ledger_export_multimonth`. Replace this with real ERP exports in
your own deployment.

## Status

Personal learning project — built to practice dbt, Airflow, Docker, and
data pipeline design against a domain (Polish accounting/ERP data) I have
direct professional familiarity with.
