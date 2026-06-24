with vat_by_months as (
select
	posting_month_num,
	sum(case when vat_category = 'input' then total_vat else 0 end) as total_input_vat,
	sum(case when vat_category like 'output%' then total_vat else 0 end) as total_output_vat
from {{ ref ('mart_vat_summary') }}
group by 1
)

select 
abs(total_input_vat - total_output_vat) out_of_bounds
from vat_by_months
where abs(total_input_vat - total_output_vat) > 20000

