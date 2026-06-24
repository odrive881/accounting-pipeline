{{
	config(materialized='table')
}}

with ledger as (

	SELECT * FROM {{ ref('stg_ledger') }}

),


--Amount owed
invoices AS (

    SELECT
        document_number,
        document_category,
		invoice_number,
        posting_date,
		credit_account,
        counterparty_name,
        counterparty_nip,
        amount_pln                  AS invoice_amount_pln,
        currency,
        amount_original,
		description

    FROM ledger

    WHERE
        document_category = 'purchase_invoice'
        AND credit_account LIKE '210%' 

),


--Amount paid
payments AS (

    SELECT
        document_number,
        posting_date                AS payment_date,
        debit_account               AS supplier_account,
        amount_pln                  AS payment_amount_pln

    FROM ledger

    WHERE
        document_category = 'bank_statement'
        AND debit_account LIKE '210%'

),


--Joining amount owed to amount paid, use invoice reference number
invoice_status AS (

    SELECT
        i.document_number,
        i.invoice_number,
        i.posting_date              AS invoice_date,
        i.counterparty_name,
        i.counterparty_nip,
        i.invoice_amount_pln,
		i.credit_account,
        i.currency,
        p.payment_date,
        p.payment_amount_pln,

        CASE
            WHEN p.payment_date IS NOT NULL THEN 'paid'
            ELSE 'outstanding'
        END                         AS payment_status,


        CASE
            WHEN p.payment_date IS NOT NULL
                THEN (p.payment_date - i.posting_date)
            ELSE
                (MAX(i.posting_date) OVER () - i.posting_date)
        END                         AS days_outstanding

    FROM invoices i
    LEFT JOIN payments p
        ON i.credit_account = p.supplier_account
)

SELECT * FROM invoice_status