class OrdersDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  def_delegator :@view, :number_to_currency
  def_delegator :@view, :link_to
  def_delegator :@view, :raw
  def_delegator :@view, :order_status_severity_class

  # delegate :order_status_severity_class, :params, :h, :raw, :link_to, :number_to_currency, to: :@view

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      id: { source: 'Order.id' },
      code: { source: 'Performance.performance_code', cond: filter_by_code },
      name: { source: 'Address.full_name' },
      seats: { source: 'Seat.location'},
      status: { source: 'Order.status' },
    }
  end

  def additional_data
    {
      code: '',
      visits: '',
      total: '',
      description: '',
    }
  end

  def data
    records.map do |order|
      {
        id: link_to(order.id, [:admin, order]),
        code: order.display_code,
        name: format_name_for_table(order),
        seats: order.seats.map { |s| s.seat.location }.sort.join(', '),
        status: raw("<span class=\"label #{order_status_severity_class(order.status)}\">#{order.status}</span>"),
        visits: order.address.nil? ? "n/a" : (current_user.is_theater_user? ? order.address.orders_processed(@current_user.theater_ids) : order.address.orders_processed ),
        total: number_to_currency(order.total),
        description: order.description,
        DT_RowID: order.id
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

#
private

  def get_raw_records
    Order.accessible_by(current_user.ability).includes(:address, :payments, seats: :seat, performance: :production).references(:address,:payments,:performance, :seats, :seat)
  end

  def sort_records(records)
    records.order(id: :desc)
  end

  def filter_by_code
    ->(column) { case column.downcase
                  when 'donation'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('DonationOrder')
                  when 'flexpass'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('FlexPassOrder')
                  when 'membership', 'member'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('MembershipOrder')
                  else
                    ::Arel::Nodes::SqlLiteral.new('performances.performance_code').matches("#{column}%")
                  end
                }
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def format_name_for_table(order)
    if order.address.nil?
      "???"
    else
      display = ""
      display += "<br/>(h/u #{order.hold_under})" unless order.hold_under.blank?
      link_to(order.address.full_name, [:admin, order.address]) + raw(display)
    end
  end

  def filter_column_condition
    ->(column) { column.table[column.field].eq(column.search.value) }
  end

  # def fetch_orders
  #   orders = Order.order("#{sort_clause}").includes(:address,:payments,:performance => :production  )
  #   orders = orders.page(page).per_page(per_page)
  #   where_text, bind_vars = where_clause
  #   orders = orders.where(where_text, *bind_vars)
  #   #if params[:sSearch].present?
  #     # orders = orders.where("name like :search or category like :search", search: "%#{params[:sSearch]}%")
  #   #end
  #   orders
  # end

  # def page
  #   params[:start].to_i/per_page + 1
  # end
#
  # def per_page
  #   params[:length].to_i > 0 ? params[:length].to_i : 10
  # end

  #def column_mapping
  #  %w[orders.id code addresses.full_name orders.status orders.description]
  #end

  # def sort_clause
  #   columns = column_mapping
  #   unless params[:order].nil?
  #     sort_list = params[:order].keys.map{|key|
  #       if params[:order][key].has_key?("column")
  #         use_c = columns[params[:order][ke                                                                                                                      ["column"].to_i]
  #         use_c = case use_c
  #           when 'addresses.full_name'
  #             "ifnull(addresses.last_name, ifnull(addresses.first_name, addresses.full_name))"
  #           when 'code'
  #             "CASE orders.type WHEN 'TicketOrder' THEN performances.performance_code ELSE orders.type END"
  #           else
  #             use_c
  #         end
  #       end
  #       use_c += " #{sort_direction(key)}"
  #     }.join(',')
  #   else
  #     ""
  #   end
  # end

  # def where2_clause
  #   if defined? @current_user
  #     active_productions_only = true
  #     conditions = []
  #     bind_variables = []
#
  #     sort_list = params[:columns].keys.each {|idx|
  #       search_text = params[:columns][idx][:search][:value]
  #       unless search_text.blank?
  #         field = column_mapping[idx.to_i]
  #         case field
  #         when 'addresses.full_name'
  #           conditions << '((addresses.full_name REGEXP ?) OR (orders.hold_under REGEXP ?))'
  #           bind_variables << search_text.upcase
  #           bind_variables << search_text.upcase
  #           active_productions_only = false
  #         when 'code'
  #           if 'MEMBERSHIP' == search_text.upcase
  #             conditions << 'orders.type = \'MembershipOrder\''
  #             active_productions_only = false
  #           elsif 'FLEXPASS' == search_text.upcase
  #             conditions << 'orders.type = \'FlexPassOrder\''
  #             active_productions_only = false
  #           elsif 'DONATION' == search_text.upcase
  #             conditions << 'orders.type = \'DonationOrder\''
  #             active_productions_only = false
  #           else
  #             conditions << 'performances.performance_code like ?'
  #             bind_variables << "%#{search_text.upcase}%"
  #           end
  #         when 'orders.id'
  #           conditions << "#{field} = ?"
  #           bind_variables << search_text.upcase
  #           active_productions_only = false
  #         when 'orders.status'
  #           unless search_text.eql?('any')
  #             conditions << "#{field} = ?"
  #             bind_variables << search_text
  #           end
  #         else
  #           # conditions << "/* unknown #{field} */"
  #         end
  #       end
  #     }
  #     if active_productions_only then
  #       conditions << "(productions.status != ? || (orders.type != 'TicketOrder'))"
  #       bind_variables << Production::INACTIVE
  #     end
  #     if @current_user.is_theater_user? then
  #       conditions << "productions.theater_id in (select id from theaters where id in (?))"
  #       bind_variables << @current_user.theater_ids
  #     end
  #     sql = conditions.each { |condition| "(#{condition})" }.join(' AND ')
  #     [sql, bind_variables]
  #   else
  #     ['0=1',Array.new]
  #   end
  # end

  # def sort_direction(key)
  #   params[:order][key]["dir"] == "desc" ? "desc" : "asc"
  # end
end