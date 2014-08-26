class OrdersDatatable

  delegate :permitted_to?, :order_status_severity_class, :params, :h, :raw, :link_to, :number_to_currency, to: :@view

  def initialize(view, current_user)
    @view = view
    @current_user = current_user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: Order.count,
      iTotalDisplayRecords: orders.total_entries,
      aaData: data
    }
  end

private

  def data
    if defined? @current_user
      orders.map do |order|
        [
          #link_to(product.name, product),
          #h(product.category),
          #h(product.released_on.strftime("%B %e, %Y")),
          #number_to_currency(product.price)
          link_to(order.id, [:admin, order]),
          order.display_code,
          order.address.nil? ? '???' : link_to(order.address.full_name, [:admin, order.address]),
          raw("<span class=\"label #{order_status_severity_class(order.status)}\">#{order.status}</span>"),
          order.address.nil? ? "n/a" : (permitted_to?(:view_full_history,:admin_orders) ? order.address.orders_processed : order.address.orders_processed(@current_user.theater_ids)),
          number_to_currency(order.total),
          h(order.description),
          order.id
        ]
      end
    else
      [ '','','','','','','','']
    end
  end

  def orders
    @orders ||= fetch_orders
  end

  def fetch_orders
    orders = Order.order("#{sort_clause}").includes(:address,:payments,:performance => :production  )
    orders = orders.page(page).per_page(per_page)
    where_text, bind_vars = where_clause
    orders = orders.where(where_text, *bind_vars)
    if params[:sSearch].present?
      # orders = orders.where("name like :search or category like :search", search: "%#{params[:sSearch]}%")
    end
    orders
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
    if defined? @current_user
      active_productions_only = true
      conditions = []

      sort_list = params[:columns].keys.each {|idx|
        search_text = params[:columns][idx][:search][:value]
        unless search_text.blank?
          field = column_mapping[idx.to_i]
          case field
          when 'addresses.full_name'
            conditions << ['addresses.full_name REGEXP ?', search_text.upcase]
            active_productions_only = false
          when 'code'
            if 'MEMBERSHIP' == search_text.upcase
              conditions << 'orders.type = \'MembershipOrder\''
              active_productions_only = false
            elsif 'FLEXPASS' == search_text.upcase
              conditions << 'orders.type = \'FlexPassOrder\''
              active_productions_only = false
            else
              conditions << ['performances.performance_code like ?',"%#{search_text.upcase}%"]
            end
          when 'orders.id'
            conditions << ["#{field} = ?",search_text.upcase]
            active_productions_only = false
          when 'orders.status'
            conditions << ["#{field} = ?",search_text] unless search_text.eql?('any')
          else
            # conditions << "/* unknown #{field} */"
          end
        end
      }
      conditions << ["(productions.status != ? || (orders.type != 'TicketOrder'))", Production::INACTIVE] if active_productions_only
      if @current_user.is_theater_user?
        conditions << ["productions.theater_id in (select id from theaters where id in (?))", @current_user.theater_ids]
      end
      bind_variables = []
      sql = conditions.map {|condition|
        if condition.is_a?(Array)
          text = condition[0]
          bind_variables << condition[1]
        else
          text = condition
        end
        "(#{text})"
      }.join(' AND ')
      [sql, bind_variables]
    else
      ['0=1',Array.new]
    end
  end

  def sort_direction(key)
    params[:order][key]["dir"] == "desc" ? "desc" : "asc"
  end
end