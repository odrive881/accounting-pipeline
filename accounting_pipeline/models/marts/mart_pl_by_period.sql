
{{
    config(materialized='table')
}}

WITH ledger AS (

	SELECT * FROM {{ ref('stg_ledger') }}

),


pl_lines AS (

    SELECT
        document_number,
        document_category,
        amount_pln,
        account_category,
        posting_month_num,
        posting_year
    FROM ledger
    WHERE document_category IN (
        'purchase_invoice',
        'sales_invoice',
        'bank_statement',
        'credit_note'
    )
      AND debit_group NOT IN ('1', '223-1', '222-1')
      AND credit_group NOT IN ('1', '223-1', '222-1')

),

aggregated AS (

    SELECT
        posting_month_num,
        account_category,
        ROUND(SUM(amount_pln)::numeric, 2) AS total_pln,
        COUNT(document_number) AS document_count
    FROM pl_lines
    GROUP BY
        posting_month_num,
        account_category

)

SELECT
    posting_month_num,

    SUM(
        CASE
            WHEN account_category = 'revenue' THEN total_pln
            ELSE 0
        END
    ) AS total_revenue,

    SUM(
        CASE
            WHEN account_category = 'cost' THEN total_pln
            ELSE 0
        END
    ) AS total_cost,

    SUM(
        CASE
            WHEN account_category = 'revenue' THEN total_pln
            ELSE 0
        END
    )
    -
    SUM(
        CASE
            WHEN account_category = 'cost' THEN total_pln
            ELSE 0
        END
    ) AS revenue_minus_cost

FROM aggregated
GROUP BY posting_month_num
ORDER BY posting_month_num

	
	
