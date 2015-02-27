PATH=$PATH:/usr/local/bin

echo "HOUSE COUNTS" > /tmp/house_counts.tmp.txt

echo "select perf.performance_code Code,
       sum(case when o.status in ('Processed','Fulfilled') then li.ticket_count else 0 end) Sold,
       sum(case when o.status in ('Hold') then li.ticket_count else 0 end) Held, 
       (capacity - sum(ifnull(li.ticket_count,0))) \"Remaining\",
       max(tix.ticket_price) \"Max Price\"
from performances perf
       left outer join (orders o, line_items li, ticket_classes tc1) on (perf.id = o.performance_id and o.id = li.order_id and li.ticket_class_id = tc1.id and tc1.holds_seats = 1)
       left join (productions prod)
     on (perf.production_id = prod.id),
     (select perf2.id, tca.available, max(tc.ticket_price) ticket_price
      from performances perf2 left join (ticket_class_allocations tca, ticket_classes tc) 
                        on (tca.performance_id = perf2.id and tca.ticket_class_id = tc.id and tc.web_visible = 1 and tca.available = 1) group by perf2.id) tix
where (li.type is null or  li.type = 'TicketLineItem')
and (o.status is null or o.status in ('Processed','Fulfilled','Hold'))
and perf.status != 'Inactive'
and prod.status != 'Inactive'
and year(perf.performance_date)*100 + week(perf.performance_date,5) >= year(curdate())*100 + week(curdate(),5)
and year(perf.performance_date)*100 + week(perf.performance_date,5) < year(adddate(curdate(), interval 14 day))*100 + week(adddate(curdate(), interval 14 day),5)
and perf.performance_date >= curdate()
and perf.id = tix.id 
group by prod.id, perf.performance_code
order by perf.performance_date, perf.performance_time, performance_code" | /usr/local/bin/mysql --table=true -u stagemgr_prod -piaj4tic5cir stagemgr >> /tmp/house_counts.tmp.txt
echo "Generated at `date`" >> /tmp/house_counts.tmp.txt
mv /tmp/house_counts.tmp.txt /tmp/house_counts.txt
