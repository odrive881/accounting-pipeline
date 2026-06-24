
{{
    config(materialized='table')
}}

WITH ledger AS (

	-- SELECT * FROM {{ ref('stg_ledger') }}

	select * from staging.stg_ledger
),



pl_lines as (
 
select
document_number,
document_category,
amount_pln,
account_category, 
posting_month_num,
posting_year
from ledger

where document_category in (
'purchase_invoice',
'sales_invoice',
'bank_statement',
'credit_note'
)

--TRANSFORM THIS TO BE DRAWING FROM THE ADDITION
and debit_group not in ('1', '223-1', '222-1')
and credit_group not in ('1', '223-1', '222-1')

),

aggregated as (

select 
	posting_month_num,
	account_category,
	round(sum(amount_pln)::numeric, 2) as total_pln,
	count(document_number) as document_count
from pl_lines
group by 1, 2

)

select
	posting_month_num,
	sum(case when account_category = 'revenue' then total_pln else 0 end) as total_revenue,
	sum(case when account_category = 'cost' then total_pln else 0 end) as total_cost,
	
	sum(case when account_category = 'revenue' then total_pln else 0 end)
	- 
	sum(case when account_category = 'cost' then total_pln else 0 end) as revenue_minus_cost
	
from aggregated
group by posting_month_num
order by posting_month_num


	
	
