
{{
	config(materialized='table')
}}

with ledger as (

	SELECT * FROM {{ ref('stg_ledger') }}

),




vat_accounts as ( 

select 
	document_number,
	document_category,
	posting_month_num,
	credit_account,
	debit_account,
	amount_pln,
	description
from ledger

where debit_account = '222-1' or debit_account = '223-1'
),


vat_categories as (

select *,
	case
		when credit_account = '222-0' then 'output_exp_0_pct'
		when debit_account = '222-1' then 'output'
		when debit_account = '223-1' then 'input'
	end as vat_category
from vat_accounts

),


vat_totals as (

select 
	posting_month_num,
	vat_category,
	sum(amount_pln) as total_vat,
	count(document_number) as document_count
from vat_categories
group by 1, 2

)

select * from vat_totals
