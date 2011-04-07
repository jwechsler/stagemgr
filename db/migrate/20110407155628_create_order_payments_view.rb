class CreateOrderPaymentsView < ActiveRecord::Migration
  def self.up
     sql = <<-SQL
     create or replace view order_payments
     as
     select o.id order_id, o.created_at, o.performance_id,
            round(sum(case p.type when 'PriceOverridePayment' then 0 else p.amount end),2) gross_amount, 
            case sum(abs(p.amount)) when 0 then 0 else
                 round(sum(case type when 'CreditCardPayment' then 
                                     (case card_type when 'American Express' then 0.30 + abs(p.amount) * .052 
                                            else 0.21 + abs(p.amount)*.052
                                     end) 
                      else 0 
                      end),2) end finance_fee 
     from payments p left join (orders o) on (p.order_id = o.id)
     where p.type != 'PriceOverridePayment'
     group by o.id 
     SQL
     execute sql
  end

  def self.down
    sql = <<-SQL 
    drop view order_payments 
    SQL
    execute sql
  end
end
