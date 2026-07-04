class TransferOwnershipTask < OrderTask
  protected

  def execute!
    result = false
    Address.transaction do
      new_owner = Address.new(full_name: order.recipient_name, email: order.recipient_email)
      new_owner = new_owner.find_original || new_owner
      raise ActiveRecord::Rollback unless new_owner.save

      order.address = new_owner
      raise ActiveRecord::Rollback unless order.save

      result = true
    end
    result
  end
end
