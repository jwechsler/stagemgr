class LinkToAddressOfRecordTask < OrderTask

  protected
  def execute!
    if order.finalized?
      morder.link_to_address_of_record
      true
    else
      false
    end

  end

end
