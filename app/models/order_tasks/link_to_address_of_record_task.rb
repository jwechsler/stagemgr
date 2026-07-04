class LinkToAddressOfRecordTask < OrderTask
  protected

  def execute!
    if order.finalized?
      order.link_to_address_of_record
      true
    else
      false
    end
  end
end
