class ServiceItemTemplate < ApplicationRecord
  validates :name, uniqueness: true
  validates :amount, numericality: true
  validates :description, presence: true

  before_validation :set_internal_description

  def attributes_for_service_item
    { description: description, internal_description: internal_description,
      amount: amount, facility_fee: facility_fee,
      suppress_for_pass_payments: suppress_for_pass_payments }
  end

  def self.selectable
    ServiceItemTemplate.order(:name).where(user_selectable: true)
  end

  def name_and_description
    "#{name}: #{internal_description}"
  end

  private

  def set_internal_description
    return if internal_description.present?

    self.internal_description = description
  end
end
