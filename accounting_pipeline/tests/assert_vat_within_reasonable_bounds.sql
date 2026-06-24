WITH vat_by_months AS (

    SELECT
        posting_month_num,
        SUM(
            CASE
                WHEN vat_category = 'input' THEN total_vat
                ELSE 0
            END
        ) AS total_input_vat,
        SUM(
            CASE
                WHEN vat_category LIKE 'output%' THEN total_vat
                ELSE 0
            END
        ) AS total_output_vat
    FROM {{ ref('mart_vat_summary') }}
    GROUP BY posting_month_num

)

SELECT
    ABS(total_input_vat - total_output_vat) AS out_of_bounds
FROM vat_by_months
WHERE ABS(total_input_vat - total_output_vat) > 20000;