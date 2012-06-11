xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml.rows do
  xml.currentpage params[:page]
  xml.totalpages @total_pages
  xml.totalrecords @total_records
  @orders.each do |o|
    xml.row :id => o.id do
      xml.cell o.id
      xml.cell o.display_code
      xml.cell o.address.try(:last_name).to_s
      xml.cell o.address.try(:first_name).to_s
      xml.cell number_to_currency(o.total)
      xml.cell o.all_line_items.map{|li|li.ticket_count}.sum
      xml.cell o.status
      if permitted_to? :view_full_history,:admin_orders
        if o.address.nil?
          xml.cell "n/a"
        else
          xml.cell o.address.orders_processed unless o.address.nil?
        end
      else
        o.address.orders_processed(current_user.theater_ids)
      end
      xml.cell o.to_s
    end
  end
end
