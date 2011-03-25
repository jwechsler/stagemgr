select o.id "Order ID", concat (a.first_name, ' ', a.last_name) Name, convert_tz(o.created_at,'UTC','SYSTEM') ordered_on
from orders o left join addresses a on (o.address_id = a.id)
where o.status = 'Processed' and
o.id in (select order_id from line_items where type = 'FlexPassLineItem');
