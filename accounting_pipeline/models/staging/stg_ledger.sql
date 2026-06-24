WITH source AS (

SELECT * FROM {{ source('accounting_pipeline', 'raw_ledger') }}

-- select * from raw.raw_ledger

),

cleaned AS (

select 
	document_number,
	
   		CASE document_type
            WHEN 'FV' THEN 'purchase_invoice'
            WHEN 'FS' THEN 'sales_invoice'
            WHEN 'WB' THEN 'bank_statement'
            WHEN 'PK' THEN 'journal_entry'
            WHEN 'NK' THEN 'credit_note'
            ELSE 'other'
		END AS document_category,

	CASE 
		WHEN document_type = 'NK' THEN true
		WHEN amount_pln_raw < 0 THEN true
		ELSE false
	END AS is_correction,
		
	
	document_date_raw::date as document_date,
	posting_date_raw::date as posting_date,

	EXTRACT(YEAR FROM posting_date_raw::DATE) AS posting_year,
	EXTRACT(MONTH FROM posting_date_raw::DATE) AS posting_month_num,

	debit_account AS debit_account,
	credit_account AS credit_account,



	--Creates clean parent account columns. Drops any custom analytical account names that might throw off later parsing logic:
	CASE
	WHEN SPLIT_PART(debit_account, '-', 2) IN ('KLIENT', 'DOSTAWCA', 'ZUS', 'US') THEN SPLIT_PART(debit_account, '-', 1)
	WHEN SPLIT_PART(debit_account, '-', 2) IN ('0', '1', '2') THEN debit_account
	WHEN SPLIT_PART(debit_account, '-', 2) IN ('') THEN debit_account
	END AS debit_account_parent,
	
	CASE 
	WHEN SPLIT_PART(credit_account, '-', 2) IN ('KLIENT', 'DOSTAWCA', 'ZUS', 'US') THEN SPLIT_PART(credit_account, '-', 1)
	WHEN SPLIT_PART(credit_account, '-', 2) IN ('0', '1', '2') THEN credit_account
	WHEN SPLIT_PART(credit_account, '-', 2) IN ('') THEN credit_account
	END AS credit_account_parent,




	LEFT(debit_account, 1) AS debit_group,
	LEFT(credit_account, 1) AS credit_group,
	
	amount_original_raw as amount_original,
	currency,
		CASE 
			WHEN currency = 'PLN' then true
			ELSE false
		END AS is_in_pln,
		
	amount_pln_raw as amount_pln,
	exchange_rate_raw as exchange_rate,
	
	description,
	counterparty_name,
	counterparty_nip,
	
	invoice_number,

	accounting_period,
	
	entered_by,
	entered_at_raw::timestamp as entered_at


	FROM source

	WHERE amount_pln_raw IS NOT NULL
),

validated as (

SELECT *
FROM cleaned c
LEFT JOIN staging.chart_of_accounts coa on c.debit_account_parent = coa.account_code

)

SELECT * FROM validated
