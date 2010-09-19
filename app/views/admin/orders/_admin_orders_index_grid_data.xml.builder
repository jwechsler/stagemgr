xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml.rows do
  xml.currentpage params[:page]
  xml.totalpages ((@order_count / params[:rows].to_i)+1)
  xml.totalrecords @order_count
  @orders.each do |o|
    xml.row :id => o.id do
      xml.cell o.id
      xml.cell o.production_code
      xml.cell o.performance.nil_or.production.nil_or.status
      xml.cell o.performance_code
      xml.cell o.performance.nil_or.status
      xml.cell o.address.try(:last_name).to_s + ", " + o.address.try(:first_name).to_s
#      xml.cell o.address.try(:first_name)
      xml.cell number_to_currency(o.total)
      xml.cell o.line_items.map{|li|li.ticket_count}.sum
      xml.cell o.status
#      xml.cell o.payment_type
      xml.cell o.updated_at.to_s :short_date_and_time
    end
  end
end
