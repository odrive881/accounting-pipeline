WITH total_balance AS (

    SELECT
        document_number,
        SUM(
            CASE
                WHEN debit_account != '' THEN amount_pln
                ELSE 0
            END
        ) AS total_debit,
        SUM(
            CASE
                WHEN credit_account != '' THEN amount_pln
                ELSE 0
            END
        ) AS total_credit
    FROM {{ ref('stg_ledger') }}
    GROUP BY document_number

)

SELECT *
FROM total_balance
WHERE ABS(total_debit - total_credit) > 0.01