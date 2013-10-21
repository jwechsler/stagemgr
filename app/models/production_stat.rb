class ProductionStat < ActiveRecord::Base

  belongs_to :production
  has_many :sales_snapshots
  def update
    self.total_ticket_sales = 0
    self.number_of_tickets = 0

    self.production.ticket_orders.each do |order|
      if order.settled?
        self.total_ticket_sales += order.total
        self.number_of_tickets += order.number_of_tickets
      end
    end

    self.average_ticket_price = self.total_ticket_sales/self.number_of_tickets if self.number_of_tickets > 0

  end

  def snapshot(as_of_date = Date.today, force_recalc = false)
    as_of_date = as_of_date.to_date
    unless as_of_date > self.production.closing_at
    snapshots = SalesSnapshot.where('production_stat_id = ? and as_of_date = ?', self.id, as_of_date)
    if !snapshots.empty? && force_recalc
      snapshots.first.destroy
      snapshots = []
    end
    if snapshots.empty?
      snapshot = self.sales_snapshots.create(:as_of_date=>as_of_date,
        :advance_sales=>Payment.sum(:amount,
          :conditions => ['order_id in (select id from orders where status in (?) and performance_id in (select id from performances where production_id=? and performance_date >= ?)) and payments.processed_on < ?',
                         Order.settled_statuses, self.production_id, as_of_date, as_of_date + 1.day]),
        :advance_seats=>TicketLineItem.sum(:ticket_count, :include=>[:ticket_class],
          :conditions => ['ticket_classes.holds_seats=? and order_id in (select orders.id from orders where orders.status in (?) and performance_id in (select id from performances where production_id=? and performance_date >= ?)) and line_items.created_at < ?',
                         true,
                         Order.settled_statuses, self.production_id, as_of_date, as_of_date + 1.day]),
        :daily_sales=>Payment.sum(:amount,
          :conditions => ['order_id in (select id from orders where status in (?) and performance_id in (select id from performances where production_id=?)) and payments.processed_on >= ? and payments.processed_on < ?',
                          Order.settled_statuses, self.production_id, as_of_date, as_of_date + 1.day]),
        :sales_to_date=>Payment.sum(:amount,
          :conditions => ['order_id in (select id from orders where status in (?) and performance_id in (select id from performances where production_id=?)) and payments.processed_on < ?',
                         Order.settled_statuses, self.production_id, as_of_date + 1.day]),
        :seats_to_date=>TicketLineItem.sum(:ticket_count, :include=>[:ticket_class],
          :conditions => ['ticket_classes.holds_seats=? and order_id in (select orders.id from orders where orders.status in (?) and performance_id in (select id from performances where production_id=?)) and line_items.created_at < ?',
                         true,
                         Order.settled_statuses, self.production_id, as_of_date + 1.day]))
    else
      snapshot = snapshots.first
    end
  else
    snapshot = self.snapshots.sort{|a1,a2| a1.as_of_date <=> a2.as_of_date }.first
  end
    snapshot
  end

  def build_pending_snapshots
    unless !self.last_snapshot_calculated.nil? && self.last_snapshot_calculated >= self.production.closing_at
      first_date = Order.minimum(:created_at,
        :conditions => ['performance_id in (select id from performances where production_id = ?)', self.production_id])
      first_date = Date.today if first_date.nil?

      first_date = [first_date, self.last_snapshot_calculated.to_date+1.day].max unless self.last_snapshot_calculated.nil?
      last_date = [self.production.closing_at.to_date, self.production.closing_at.to_date].min
      c_date = first_date
      while c_date <= last_date do
        self.snapshot(c_date, true)
        c_date += 1.day
      end
      self.last_snapshot_calculated = DateTime.now
    end

  end

end
