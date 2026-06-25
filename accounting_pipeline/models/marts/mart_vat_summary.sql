
{{
	config(materialized='table')
}}

WITH ledger AS (

    SELECT *
    FROM {{ ref('stg_ledger') }}

),

vat_accounts AS (

    SELECT
        document_number,
        document_category,
        posting_month_num,
        credit_account,
        debit_account,
        amount_pln,
        description
    FROM ledger
    WHERE debit_account = '222-1'
       OR debit_account = '223-1'

),

vat_categories AS (

    SELECT
        *,
        CASE
            WHEN credit_account = '222-0' THEN 'output_exp_0_pct'
            WHEN debit_account = '222-1' THEN 'output'
            WHEN debit_account = '223-1' THEN 'input'
        END AS vat_category
    FROM vat_accounts

),

vat_totals AS (

    SELECT
        posting_month_num,
        vat_category,
        SUM(amount_pln) AS total_vat,
        COUNT(document_number) AS document_count
    FROM vat_categories
    GROUP BY
        posting_month_num,
        vat_category

)

SELECT *
FROM vat_totals