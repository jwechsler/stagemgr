select t.name, prod.name, '' performance_date, '       ' time,
       sum(num_sold) house_count, sum(gross_amount) gross_amount, sum(finance_fee) finance_fee, sum(facility_fee) facility_fee, sum(gross_amount) - sum(finance_fee) - sum(facility_fee) due 
from (
  select o.performance_id, li.ticket_class_id,
         round(sum(tc.ticket_price*abs(li.ticket_count)),2) face_value, 
         sum(ticket_count) num_sold, 
         round(sum(tc.ticketing_fee * abs(li.ticket_count)),2) facility_fee,  o.payment_type 
  from line_items li left join (orders o) on (li.order_id = o.id) 
       left outer join (ticket_classes tc) on (li.ticket_class_id = tc.id)
  where o.status in ('Fulfilled','Refunded','Processed')  and li.type = 'TicketLineItem'
  group by performance_id) order_items,  
  (select performance_id, sum(gross_amount) gross_amount, sum(finance_fee) finance_fee from order_payments group by performance_id) perf_payments,
  performances perf,
  productions prod,
  theaters t
where perf.id = perf_payments.performance_id and 
perf.id = order_items.performance_id and
prod.id = perf.production_id and
perf.status != 'Inactive' and
prod.theater_id = t.id
and (prod.production_code = @prod_code or (prod.status != 'Inactive' and prod.theater_id  = @theater_id) or @all_shows=1)
group by prod.id
order by t.name, prod.name, perf.performance_date, perf.performance_time;

