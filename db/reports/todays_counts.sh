#!/bin/bash

PATH=$PATH:/usr/local/mysql/bin

echo "select date_format(sold_on, '%Y-%m-%d') sold_on, prod.name, 
       count(*) orders, sum(num_sold) num_sold, format(sum(amt_paid),2) Amount
from (
  select convert_tz(o.created_at,'UTC','SYSTEM') sold_on, li.order_id, o.performance_id, li.ticket_class_id, 
         sum(ticket_count) num_sold, pay.amt amt_paid,
         round(sum(tc.ticketing_fee * li.ticket_count),2) facility_fee,  o.payment_type 
  from line_items li left join (orders o) on (li.order_id = o.id) 
       left outer join (ticket_classes tc) on (li.ticket_class_id = tc.id),
       (select order_id, sum(amount) amt from payments group by order_id) pay
  where o.status in ('Fulfilled','Processed') and li.ticket_count > 0 and li.type = 'TicketLineItem'
        and pay.order_id = o.id
  group by order_id, ticket_class_id) order_items,
  ticket_classes,
  performances perf,
  productions prod
where 
ticket_classes.id = order_items.ticket_class_id and
perf.id = order_items.performance_id and
prod.id = perf.production_id and
       perf.status <> 'Inactive' and
       prod.status <> 'Inactive' and
date_format(convert_tz(sold_on,'UTC','SYSTEM'),'%Y-%m-%d') = curdate()
group by prod.id, date_format(sold_on, '%Y-%m-%d')
order by prod.name, perf.performance_date desc;" | mysql --table=true -u stagemgr_prod stagemgr

