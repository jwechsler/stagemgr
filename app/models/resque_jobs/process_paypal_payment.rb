class ProcessPaypalPayment
  @queue = :sync

  def self.perform(params)
    o = Order.find(params['invoice'].to_i)
    raise "Could not find order #{params['invoice']}" if o.nil?

    p = Payment.find_by_transaction_id_and_order_id(params['txn_id'], params['invoice'].to_i)
    raise "Could not find payment with transaction #{params['transaction_id']}" if p.nil?
    raise "Mismatched payment/order combination.  Payment #{p.id} does not match order #{o.id}" if p.order_id != o.id

    p.save!
  end
end
