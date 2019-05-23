class OrderImport
  protected
  def self.new_address_tag(theater_id, address, tag_label, tag_value)
    sub_tag = AddressTag.new
    sub_tag.address = address
    sub_tag.tag_label = tag_label
    sub_tag.tag_value = tag_value
    sub_tag.theater_id = theater_id
    sub_tag
  end
end
