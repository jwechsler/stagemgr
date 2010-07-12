xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml.rows do
  xml.currentpage params[:page]
  xml.totalpages ((@order_count / params[:rows].to_i)+1)
  xml.totalrecords @order_count
  @orders.each do |o|
    xml.row :id => o.id do
      xml.cell o.id
      xml.cell o.production_code
      xml.cell o.performance_code
      xml.cell o.address.last_name
      xml.cell o.address.first_name
      xml.cell o.total
      xml.cell o.status
      xml.cell o.payments.first.card_last_four
      xml.cell o.updated_at
    end
  end
end