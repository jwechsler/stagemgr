select t.name, prod.name, perf.performance_date, date_format(perf.performance_time, '%l:%i %p') time,
       sum(num_sold) house_count, sum(gross_amount) gross_amount, sum(finance_fee) finance_fee, sum(facility_fee) facility_fee, sum(gross_amount) - sum(finance_fee) - sum(facility_fee) due 
from (
  select o.performance_id, li.ticket_class_id,
         round(sum(tc.ticket_price*abs(li.ticket_count)),2) face_value, 
         sum(ticket_count) num_sold, 
         round(sum(tc.ticketing_fee * abs(li.ticket_count)),2) facility_fee,  o.payment_type 
  from line_items li left join (orders o) on (li.order_id = o.id) 
       left outer join (ticket_classes tc) on (li.ticket_class_id = tc.id)
  where o.status in ('Fulfilled','Refunded','Processed')  and li.type = 'TicketLineItem'
        and date_format(convert_tz(o.created_at,'UTC','SYSTEM'),'%Y-%m-%d') = adddate(curdate(), interval -1 day)
          group by performance_id) order_items,  
 (select o.performance_id, p.type, round(sum(p.amount),2) gross_amount, 
         case sum(abs(p.amount)) when 0 then 0 else round(sum(case type when 'CreditCardPayment' then case card_type when 'American Express' then 0.20 + abs(p.amount) * .052 else 0.21 + abs(p.amount)*.052 end else 0 end),2) end finance_fee 
   from payments p left join (orders o) on (p.order_id = o.id)
        and date_format(convert_tz(o.created_at,'UTC','SYSTEM'),'%Y-%m-%d') = adddate(curdate(), interval -1 day)
  group by o.performance_id) order_payments,
  performances perf,
  productions prod,
  theaters t
where perf.id = order_payments.performance_id and 
perf.id = order_items.performance_id and
prod.id = perf.production_id and
perf.status != 'Inactive' and
prod.theater_id = t.id
and (prod.production_code = @prod_code or (prod.status != 'Inactive' and prod.theater_id  = @theater_id) or @all_shows=1)
group by order_items.performance_id
order by t.name, prod.name, perf.performance_date, perf.performance_time;

