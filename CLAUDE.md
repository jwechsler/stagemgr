# STAGEMGR DEVELOPMENT GUIDE

## Project Overview
Stagemgr is a ticketing platform to sell tickets to end users for live events.  It supports multiple theatre venues, multiple producing companies and all necessary backend operations for box office service. 

## Stagemgr development

1. Stagemgr runs under Rails 6 and Ruby 3
2. The development environment runs in Docker. `stagemgr/docker-compose.yml` is the primary stack (app + mysql + redis); Theater Wit's workspace layers the Foundation marketing site on top of it from `../site/`.
3. Stagemgr has a dedicated git repository. Git commands MUST ALWAYS be executed from the stagemgr directory to reflect changes to stagemgr
4. RSpec tests can be run directly from the stagemgr directory without proxying through Docker:
   - Run all tests: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec`
   - Run specific test file: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec spec/models/orders/flex_pass_order_spec.rb`
   - Run specific test: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec spec/models/orders/flex_pass_order_spec.rb:10`

## Setup, Configuration and Theming

Developer documentation lives in `docs/manual/developer/` (published to
stagemgr.theaterwit.org) and `README.md`. The essentials:

- **`rake setup:*`** (`lib/tasks/setup.rake`, implementation in `lib/tasks/setup/`)
  scaffolds and checks an install: `setup:config` copies `config/*.yml.example` →
  `config/*.yml` and `.env.example` → `.env` (never overwrites, no Rails boot);
  `setup:bootstrap` creates the DB and loads `db/schema.rb`; `setup:site[slug]`
  creates a theme; `setup:wizard` runs the whole first-run sequence;
  **`setup:doctor`** is the health check — run it first when something is wrong.
  `config:setup` is a deprecated alias for `setup:config`.
- **Secrets go through `AppSecrets`** (`lib/app_secrets.rb`), never bare `ENV[]`
  or `Rails.application.credentials`. Order: non-blank ENV → encrypted
  credentials → (deprecated, `resque_admin_password` only) `config/server.yml`.
  Blank ENV counts as absent. `lib/required_secrets.rb` aborts a production web
  or resque boot when a required secret is missing from both sources.
- **House copy lives in `sites/<slug>/views/`**, selected by `site_theme:` in
  `config/server.yml`; those files shadow the same paths under `app/views/` for
  pages and mail alike. Theater Wit's copy is `sites/theaterwit/`. Never put a
  specific theater's name, phone or address in `app/`, `lib/` or `config/`. See
  `sites/README.md`.
- **Plain facts** (phone, address, pickup window, social URLs, artistic
  director) are the `theater:` block of `config/server.yml`, read through
  `TheaterInfo` / the `theater_info` view helper. The house's *name* is not a
  key — it is `Theater.default_theater.name`.
- **The test environment reads the tracked `config/server.yml.example`**, not
  your gitignored `config/server.yml` (see `config/environments/test.rb`), and
  cucumber forces `RAILS_ENV=test` too. A key the specs need goes in that file's
  `test:` block, whose sentinel values (`555-BOX-OFFICE`, `Test Director`, …)
  are asserted by specs and features.


## Stagemgr Architecture
Based on analysis of the codebase, Stagemgr consists of these key components:

1. **Core Models**:
   - Theater, Production, Performance models for event management
   - Ticket Classes and Ticket Class Allocations for inventory management
   - Order system with specialized types (TicketOrder, DonationOrder, FlexPassOrder, MembershipOrder)
   - Line Item models for different purchase types
   - Address and User models for customer management
   - SeatMap and SeatAssignment models for reserved seating
   - FlexPass and Membership models for patron benefits
   - Payment and Transaction models for financial processing

2. **Inventory Management**:
   - TicketClassAllocation system tracks availability per performance
   - HouseCount model provides real-time seat inventory tracking
   - Reserved seating with seat assignment validation
   - Wheelchair and accessibility accommodation support
   - Dynamic pricing with time-based allocations
   - Performance capacity management with overbooking prevention
   - Hold and reserved seat functionality
   - **Hybrid capacity control**: Productions automatically use seat map capacity when available, falling back to manual capacity for general admission

3. **Order Processing Workflow**:
   - Order state transitions: NEW → PROCESSING → PROCESSED → FULFILLED/UNCLAIMED
   - Specialized order processors for each order type
   - Ticket exchange system with payment adjustment
   - Order splitting functionality for multi-customer orders
   - UUID tracking throughout the order lifecycle
   - Seat assignment confirmation during checkout
   - Fee calculation based on ticket types

4. **Payment Processing**:
   - Multiple payment gateway support (Stripe primary, PayPal secondary)
   - Credit card processing with validation
   - Recurring payments for memberships
   - Stripe webhook integration
   - Refund processing with payment reversal
   - Exchange payment differential handling

5. **Metrics and Reporting**:
   - RateOfSale model for daily ticket sales analytics
   - Export framework via MetricsExporter
   - Specialized reports: Production Attendee, Membership Usage, Flex Pass Usage
   - Additional reports: Donation List, House Management, Sales by Performance
   - Weekly Box Office reports with detailed metrics
   - CSV exports with notification system
   - Customer mailing list generation

6. **Job Framework**:
   - LoggedJob and NotifyOnCompletion concerns for tracking and notifications
   - Background jobs for calculating house counts, exporting data, processing sales
   - Resque-based job scheduling with lock timeout prevention
   - JobMetadata for tracking execution history and incremental processing
   - Queue prioritization for different job types
   - Automated scheduling for recurring tasks

7. **Notification System**:
   - OrderMailer handles various types of customer communications
   - NotificationTask manages email delivery and retry logic
   - Email templates using HAML with Foundation for styling
   - Automated confirmations, receipts, and reminders
   - Customer communication tracking

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
- **Slow reporting**: Check JobMetadata execution times with `JobMetadata.order(created_at: :desc).limit(10)`
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

## Production Capacity Control

Stagemgr implements a sophisticated hybrid capacity system that automatically prevents overselling while supporting both general admission and reserved seating venues:

### Capacity Logic Implementation
```ruby
# Production#capacity method (app/models/production.rb:67-69)
def capacity
  seat_map&.capacity || read_attribute(:capacity)
end

# SeatMap#capacity method (app/models/seat_map.rb:29-31)  
def capacity
  seats.count
end
```

### How It Works
1. **Reserved Seating Productions**: When a `seat_map` is assigned, capacity automatically equals the live count of actual seats in the seat map (`seat_map.capacity`)
2. **General Admission Productions**: When no seat map is assigned, capacity uses the manually set database value (`read_attribute(:capacity)`)
3. **Real-time Updates**: Seat map capacity updates automatically as seats are added/removed from venues
4. **Safety Mechanism**: Prevents overselling by using actual seat count rather than potentially outdated manual capacity settings

### Business Impact
- **Prevents Overselling**: Productions with seat maps cannot sell more tickets than physical seats available
- **Backward Compatibility**: General admission events continue using manual capacity settings
- **Data Integrity**: Eliminates discrepancies between venue layout and ticket sales capacity
- **Real-time Accuracy**: Capacity reflects current venue configuration changes

### Usage Throughout Application
The capacity value is used for:
- **Availability Calculations**: `performance.number_of_seats_left` subtracts sold seats from capacity
- **House Count Metrics**: `house_count.total_seats = production.capacity`
- **Sold-out Detection**: `performance.sold_out?` checks if seats remaining <= 0
- **Dynamic Pricing**: Triggers pricing changes based on capacity utilization percentage
- **Near-capacity Warnings**: Alerts when approaching venue limits

### Debugging Capacity Issues
- Check effective capacity: `production.capacity`
- Verify seat map capacity: `production.seat_map&.capacity`
- Check database capacity: `production.read_attribute(:capacity)`
- Identify capacity type: `production.has_reserved_seating?` vs `production.has_general_admission?`
- Test seat count changes: Add/remove seats and verify `seat_map.capacity` updates

## Core Data Model Relationships

### Performance, Production, and Theater
```
Theater
  └── Productions (many)
       └── Performances (many)
            ├── TicketClassAllocations (many)
            └── SeatAssignments (many)
```

### Order System
```
Order (abstract base class)
  ├── TicketOrder
  │    └── TicketLineItems (many)
  │              └── SeatAssignments (optional)
  ├── DonationOrder
  │    └── DonationLineItem (one)
  ├── FlexPassOrder
  │    └── FlexPassLineItem (one)
  ├── MembershipOrder
  │    └── MembershipLineItem (one)
  ├── AllLineItems (many). Includes all possible lineitems as well as ServiceFees, SpecialOffers
  
Address ──┬── Orders (many)
          └── AddressTags (many)
```

### Inventory Management
```
TicketClass
  └── TicketClassAllocations (many)
       └── Tickets (many)

SeatMap
  └── Seats (many)
       └── SeatAssignments (many)

Performance
  └── HouseCount (one)
       └── HouseCountSnapshot (many)
```

### Payment Processing
```
Order
  └── Payments (many, STI on payments.type)
       ├── CurrencyPayment
       │    ├── CashPayment
       │    ├── CheckPayment
       │    └── CreditCardPayment      (Stripe via PaymentProcessing.gateway)
       ├── ExternalPayment              (comps and other non-currency tenders)
       ├── PassPayment
       │    ├── FlexPassPayment
       │    └── MembershipPayment
       ├── ExchangePayment              (offset on the original, credit on the new order)
       ├── PriceOverridePayment         ("Carryover" write-off)
       ├── RefundPayment                (partial refund on an exchange; payment_id -> refunded CurrencyPayment)
       ├── ReversalPayment
       └── RecurringPayment

PaymentProcessing (module) ─── StripeGateway < ActiveMerchant StripePaymentIntentsGateway
```

### Job Framework
```
LoggedJob (concern)
  └── Various Jobs
       └── JobMetadata (many)

NotifyOnCompletion (concern)
  └── Export Jobs
```

This hierarchical structure illustrates the key relationships in the Stagemgr system, showing how models connect to form the complete ticketing and theater management solution.

## Performance Monitoring and Optimization

### System Health Indicators
- **Queue depth**: High number of pending jobs in Resque queues (`Resque.info[:pending]`)
- **Worker status**: Stalled or idle workers (`Resque.workers`)
- **Failed job count**: Accumulated errors (`Resque::Failure.count`)
- **Database connections**: Pool utilization (`ActiveRecord::Base.connection_pool.stat`)
- **Redis health**: Connection status and memory usage (`redis-cli info memory`)

### Performance Bottlenecks
1. **House Count Calculations**: Especially for performances with many ticket allocations
   - Solution: Background processing and caching of counts
   
2. **Export Jobs**: Can be resource intensive for large datasets
   - Solution: Incremental processing and time window filtering
   
3. **Seat Assignment Processing**: Complex validation during checkout
   - Solution: Optimized queries and temporary locking

4. **Order Processing During High Volume**: Flash sales can create bottlenecks
   - Solution: Queue throttling and staggered processing

### Optimization Strategies
- **Indexing**: Key columns for order lookups, performance queries, and address searches
- **Caching**: Production statistics, house counts, and frequently accessed lookups
- **Background Processing**: Move intensive calculations to Resque jobs
- **Query Optimization**: Eager loading associations, limit column selection
- **Connection Pooling**: Configure appropriate pool sizes based on worker count

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

# Performance tracking
JobMetadata.where(job_class: "CalculateHouseCountsJob").order(created_at: :desc).limit(5).pluck(:execution_time)
```