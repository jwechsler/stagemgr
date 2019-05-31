#!/bin/bash

PATH=$PATH:/usr/local/bin

echo "select LEFT(prod.name,24) name,
       count(*) orders, sum(num_sold) num_sold, format(sum(amt_paid),2) Amount
from (
  select li.order_id, sum(ticket_count) num_sold
  from line_items li left join (orders o) on li.order_id = o.id
  where
        li.type = 'TicketLineItem' and o.status in ('Fulfilled','Processed','Unclaimed') and
        date_format(date_add(convert_tz(o.created_at,'UTC','SYSTEM'),INTERVAL 7 DAY),'%Y-%m-%d') > curdate()
  group by li.order_id) li_ticket_counts,
  (select order_id, sum(amount) amt_paid
   from payments left join (orders o) on payments.order_id = o.id
   where  o.status in ('Fulfilled','Processed','Unclaimed') and
        date_format(date_add(convert_tz(o.created_at,'UTC','SYSTEM'),INTERVAL 7 DAY),'%Y-%m-%d') > curdate()
   group by order_id) pay,
  productions prod,
  performances perf,
  orders
where
  li_ticket_counts.order_id = orders.id and
  orders.performance_id = perf.id and
  perf.performance_code like '$1%' and
  pay.order_id = orders.id and
  prod.id = perf.production_id and
  perf.status <> 'Inactive' and
  prod.status <> 'Inactive' and
  orders.status in ('Fulfilled','Processed','Unclaimed') and
  date_format(date_add(convert_tz(orders.created_at,'UTC','SYSTEM'),INTERVAL 7 DAY),'%Y-%m-%d') > curdate()
group by prod.id
order by prod.name, perf.performance_date desc;" | /usr/local/bin/mysql --defaults-extra-file=/Users/jeremyw/.my.cnf --table=true -u stagemgr_prod stagemgr > /tmp/last7_counts$1.txt

