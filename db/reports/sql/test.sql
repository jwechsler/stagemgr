select prod.name Production, perf.performance_code Code,
       sum(case when o.status in ('Processed','Fulfilled') then li.ticket_count else 0 end) Sold,
       sum(case when o.status in ('Hold') then li.ticket_count else 0 end) Held, 
       prod.capacity - sum(ifnull(li.ticket_count,0)) Remaining, max(tix.ticket_price) \"Max Price\"
from performances perf
       left outer join (orders o, line_items li) on (perf.id = o.performance_id and o.id = li.order_id)
       left join (productions prod)
     on (perf.production_id = prod.id),
     (select perf2.id, tca.available, max(tc.ticket_price) ticket_price
      from performances perf2 left join (ticket_class_allocations tca, ticket_classes tc) 
                        on (tca.performance_id = perf2.id and tca.ticket_class_id = tc.id and tca.available = 1) group by perf2.id) tix
where (li.type is null or  li.type = 'TicketLineItem')
and (o.status is null or o.status in ('Processed','Fulfilled','Hold'))
and perf.status != 'Inactive'
and prod.production_code = '$1'
and perf.id = tix.id 
group by prod.id, perf.performance_code
order by prod.opening_at, perf.performance_date, perf.performance_time
