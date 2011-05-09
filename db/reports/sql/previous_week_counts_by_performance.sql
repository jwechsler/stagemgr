select t.name, prod.name, perf.performance_date, date_format(perf.performance_time, '%l:%i %p') time, 
       concat(ticket_classes.class_name , ' ($',format(ticket_classes.ticket_price,2) , ')') ticket_class,
       sum(num_sold) num_sold
from (
  select li.order_id, o.performance_id, li.ticket_class_id, 
         sum(ticket_count) num_sold
  from line_items li left join (orders o) on (li.order_id = o.id) 
       left outer join (ticket_classes tc) on (li.ticket_class_id = tc.id)
  where o.status in ('Processed','Fulfilled') and li.ticket_count > 0 and li.type = 'TicketLineItem'
  group by order_id, ticket_class_id) order_items,
  ticket_classes,
  performances perf,
  productions prod,
  theaters t
where 
ticket_classes.id = order_items.ticket_class_id and
perf.id = order_items.performance_id and
perf.status != 'Inactive' and
prod.id = perf.production_id
and ((prod.status != 'Inactive' and prod.theater_id = @theater_id) or prod.production_code = @prod_code or (prod.status != 'Inactive' and @all_shows=1))
and prod.theater_id = t.id
and week(perf.performance_date,5) = week(curdate(),5)-1
group by order_items.performance_id, order_items.ticket_class_id
order by t.name, prod.id, perf.performance_date, perf.performance_time, ticket_classes.class_name;

