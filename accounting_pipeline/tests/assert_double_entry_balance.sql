with total_balance as (
select 
	document_number,
	sum(case when debit_account != '' then amount_pln else 0 end) as total_debit,
	sum(case when credit_account != '' then amount_pln else 0 end) as total_credit
from {{ ref('stg_ledger') }}
group by 1		
)

select * from total_balance
where abs(total_debit - total_credit) > 0.01 
