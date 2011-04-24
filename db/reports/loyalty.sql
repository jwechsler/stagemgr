update orders left join addresses a1 on (orders.address_id = a1.id) set address_id = (select id from addresses a2 where email is not null and trim(email) != '' and a1.email = a2.email group by email);

truncate table collapse_emails;

create table collapse_emails as select * from (select max(id) new_id, email, count(*) visits from addresses where email is not null and trim(email) != '' group by email having count(*) > 1 order by email) a2;

select addresses.id, collapse_emails.new_id from addresses, (select max(id) new_id, email, count(*) visits from addresses where email is not null and trim(email) != '' group by email having count(*) > 1 order by email) collapse_emails where (addresses.email=collapse_emails.email);

/* query to update orders to point at most recent email-unique address book record */
update orders set address_id = (select new_id from (select addresses.id, collapse_emails.new_id from addresses, (select max(id) new_id, email, count(*) visits from addresses where email is not null and trim(email) != '' group by email having count(*) > 1 order by email) collapse_emails where (addresses.email=collapse_emails.email)) remap_emails where remap_emails.id = orders.address_id)
where address_id in (select id from (select addresses.id, collapse_emails.new_id from addresses, (select max(id) new_id, email, count(*) visits from addresses where email is not null and trim(email) != '' group by email having count(*) > 1 order by email) collapse_emails where (addresses.email=collapse_emails.email)) r2);


/* report on all repeat visitors who saw _different_ productions */

select  a.first_name, a.last_name, a.email, productions.production_code, remap_emails.visits  from orders, performances, productions, addresses a, (select addresses.id, collapse_emails.new_id, visits from addresses, (select max(id) new_id, email, count(*) visits from addresses where email is not null and trim(email) != '' group by email having count(*) > 1 order by email) collapse_emails where addresses.email=collapse_emails.email) remap_emails where orders.performance_id = performances.id and performances.production_id = productions.id and orders.address_id = a.id and a.id = remap_emails.new_id group by a.first_name, a.last_name, productions.production_code having count(*) > 1 order by a.email;

