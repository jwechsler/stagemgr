class MembershipOrder < Order

  belongs_to :membership_offer
  has_many :membership_line_items, :foreign_key=>:order_id, :dependent => :destroy
  has_many :recurring_payments, :foreign_key=>:order_id
  validates_associated :membership_line_items
  accepts_nested_attributes_for :membership_offer, :membership_line_items, :recurring_payments, :allow_destroy=>true

  def display_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0", 2)
  end

  def ticket_quantity
    BigDecimal.new("0", 2)
  end

  def membership_offer
    self.membership_line_items.first.membership_offer if !self.membership_line_items.empty?
  end

  def set_membership_offer(offer)
    li = MembershipLineItem.create(:membership_offer=>offer, :address=>self.address)

    self.membership_line_items << li
  end

  def membership
    if (!self.membership_line_items.first.nil?)
      self.membership_line_items.first.membership
    else
      nil
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = Array.new
    valid_payment_types << Order::CREDIT_CARD
    valid_payment_types
  end

  def link_to_address_of_record
    super
    self.membership_line_items.each do |li|
      unless li.membership.nil?
        li.membership.address = self.address
        li.membership.save!
      end
    end
    self
  end

  def set_defaults
    super
    self.membership_line_items.each { |di| di.order=self
    di.membership.address = self.address if !di.membership.nil? }
  end

  def total(reload_line_items=false)
    self.value_of_all_payments
  end

  def create_recurring_payment(note = nil)
    payment = RecurringPayment.new
    payment.amount = self.membership.membership_offer.recurring_cost
    payment.note = note || "Automatically created"
    payment.transaction_id = self.membership.profile_id
    self.payments << payment
    payment
  end

  def create_proper_payment_in_amount_of!(amount)
    self.membership.update_from_profile!
    if self.membership.is_active? && self.membership.number_cycles_completed > 0
      create_recurring_payment
    end
  end

  protected

  def cascade_address_to_nested_items
    super
    membership_line_items.each { |li| li.address = self.address }
  end

  def unique_line_items(reload_line_items=false)
    (super + self.membership_line_items(reload_line_items)).uniq
  end

  def transition_new_to_processing!(redirect_to = nil)
    super

  end

  def create_receipt_task
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:membership_confirmation)
  end

  def create_mail_list_task
    self.tasks << MyEmmaTask.new(:execute_at=>Time.now + 5.minutes, :additional_groups=>[self.membership_offer.myemma_group]) if !self.address.email.nil?
  end

  def set_tasks_after_save
    if self.do_not_create_tasks.nil? && self.status_changed?
      case self.status
        when PROCESSED
          if self.membership.is_active? && self.membership.number_cycles_completed > 0
            self.tasks << CheckMembershipTask.new(:execute_at=>self.membership.next_billing_date + 2.hours)
          else
            self.tasks << CheckMembershipTask.new(:execute_at=>Time.now + 5.minutes)
          end
      end
    end
    super
  end

end