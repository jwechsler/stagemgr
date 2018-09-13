class AddressesDatatable
  delegate :params, :h, :raw, :link_to, :number_to_currency, to: :@view

  def initialize(view)
    @view = view
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: Address.count,
      iTotalDisplayRecords: addresses.total_entries,
      aaData: data
    }
  end

private

  def data
    addresses.map do |address|
      [
        link_to(address.full_name, [:admin, address]),
        address.email,
        permitted_to?(:view_full_history,:admin_orders) ? address.orders_processed : address.orders_processed(current_user.theater_ids)
      ]
    end
  end

  def addresses
    @addresses ||= fetch_addresses
  end

  def fetch_addresses
    if params[:search][:value].present?
      addresses = Address.where("full_name like :search or email like :search", search: "%#{params[:search][:value]}%")
    else
      addresses = Address.where('1=1')
    end
    addresses = addresses.page(page).per_page(per_page)

    addresses
  end

  def page
    params[:start].to_i/per_page + 1
  end

  def per_page
    params[:length].to_i > 0 ? params[:length].to_i : 10
  end

  def column_mapping
    %w[orders.id code addresses.full_name orders.status orders.description]
  end

  def sort_clause
    columns = column_mapping
    unless params[:order].nil?
      sort_list = params[:order].keys.map{|key|
        if params[:order][key].has_key?("column")
          use_c = columns[params[:order][key]["column"].to_i]
          use_c = case use_c
            when 'addresses.full_name'
              "ifnull(addresses.last_name, ifnull(addresses.first_name, addresses.full_name))"
            when 'code'
              "CASE orders.type WHEN 'TicketOrder' THEN performances.performance_code ELSE orders.type END"
            else
              use_c
          end
        end
        use_c += " #{sort_direction(key)}"
      }.join(',')
    else
      ""
    end
  end

  def where_clause
  end


  def sort_direction(key)
    params[:order][key]["dir"] == "desc" ? "desc" : "asc"
  end
end