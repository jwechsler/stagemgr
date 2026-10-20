---
name: stagemgr-debugging
description: Troubleshooting Stagemgr - inventory and seat discrepancies, stuck orders, payment failures, Resque job and queue problems, DB deadlocks and slow queries, capacity logic, and the console helpers for each.
---

# Stagemgr debugging reference

## Debugging Tips
- Check Rails logs at `./stagemgr/log/development.log` for errors
- Use `docker compose logs stagemgr` to check container logs
- Inspect Resque jobs with `docker compose exec -u app stagemgr bash -lc "bundle exec rails c"` (or `../site/bin/rc`) then `Resque.info`
- Most ticketing issues relate to inventory allocation or order processing
- Database-level issues can be debugged by connecting directly to MySQL

## Common Issues and Solutions

### Inventory Management Issues
- **Seat availability discrepancies**: Check HouseCount calculations via `HouseCount.recalculate_for_performance(performance_id)`
- **Overbooking errors**: Verify TicketClassAllocation records for the specific performance
- **Reserved seating conflicts**: Inspect SeatAssignment records for duplicates with `SeatAssignment.where(performance_id: X).group_by(&:seat_id).select{|k,v| v.length > 1}`
- **Zero inventory errors**: Check if performance has correct TicketClassAllocation with `Performance.find(id).ticket_class_allocations`
- **Capacity logic issues**: Check if production uses seat map capacity with `production.seat_map&.capacity` vs database capacity with `production.read_attribute(:capacity)`

### Order Processing Issues
- **Stuck orders**: Check for orders in PROCESSING state with `Order.where(state: 'PROCESSING')`
- **Payment failures**: Verify gateway logs and transaction records
- **Exchange errors**: Check for invalid price differentials or incompatible ticket classes
- **Email delivery failures**: Check NotificationTask records and mail server logs

### Background Job Issues
- **Failed jobs**: Inspect `Resque::Failure.all` for stack traces
- **Stuck jobs**: Look for worker processes or locks with `Resque.workers` and `Resque.redis.keys("*lock*")`
- **Slow reporting**: JobMetadata stores only `last_run_at`, never durations; time jobs from the Resque worker logs
- **Job last ran**: `JobMetadata.last_run("CalculateHouseCountsJob")` (epoch means it has never completed)
- **Queue backlog**: Monitor queue sizes with `Resque.size(:high)`, `Resque.size(:low)`, etc.

### Database Troubleshooting
- **Connection pool exhaustion**: Check for `ActiveRecord::ConnectionTimeoutError` in logs
- **Deadlocks**: Look for `Deadlock found when trying to get lock` in logs
- **Slow queries**: Examine logs for queries exceeding 1000ms execution time
- **Index problems**: Check query plans with `EXPLAIN` for full table scans

### Testing Utilities
- `Order.last.debug_info` - Provides comprehensive order details
- `Performance.find(id).recalculate_house_count!` - Forces house count recalculation
- `TicketClassAllocation.debug_allocation(allocation_id)` - Shows allocation details
- `Payment.where(state: "error").last(10)` - List recent failed payments
- `production.capacity` - Shows effective capacity (seat map count or database value)
- `production.seat_map&.capacity` - Shows actual seat count for reserved seating
- `production.read_attribute(:capacity)` - Shows manual capacity setting from database


## Capacity

### Debugging Capacity Issues
- Check effective capacity: `production.capacity`
- Verify seat map capacity: `production.seat_map&.capacity`
- Check database capacity: `production.read_attribute(:capacity)`
- Identify capacity type: `production.has_reserved_seating?` vs `production.has_general_admission?`
- Test seat count changes: Add/remove seats and verify `seat_map.capacity` updates

### Monitoring Commands
```ruby
# Queue monitoring
Resque.info
Resque.size(:high)
Resque.working.size

# Job failure analysis
Resque::Failure.all(0, 10)
Resque::Failure.requeue(failure_id)
Resque::Failure.clear

# Database monitoring
ActiveRecord::Base.connection.execute("SHOW PROCESSLIST").each { |p| puts p.inspect }
ActiveRecord::Base.connection.execute("SHOW ENGINE INNODB STATUS")

# When each logged job last completed successfully
