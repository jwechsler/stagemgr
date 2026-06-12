class ProductionAttendeeReport < OrderReport
  attr_reader :production, :export_emails_allowed

  def initialize(production_id, export_emails_allowed = false, reporting_user_id = nil)
    @production = Production.find(production_id)
    @export_emails_allowed = export_emails_allowed
    keys = OrderReport.columns_for_orders(true, true) +
           %i[order_total order_revenue num_tickets num_seats external_id
              opted_in_for_email marketing_source]

    keys += [:seat_assignments] if production.has_reserved_seating?
    super(keys, reporting_user_id)
    @data = []
  end

  # create
  #
  # builds a large export of orders with the following columns add
  # @param production The production to pull the orders from
  #
  # @return array [keys, value hashed by key] for each order

  def create
    members_by_email = Admin::ReportsHelper.attendees_on_email_list(production)

    theater_ids = User.find(reporting_user_id).theater_ids

    TicketOrder.settled.joins(:performance)
               .includes(:ticket_line_items, :payments, :address)
               .where(performances: { production_id: production.id })
               .find_each(batch_size: 1000) do |o| # Adjust batch_size as needed
      row = OrderReport.create_hash_from_order_fields(o)
      row[:marketing_source] = o.marketing_source
      row[:external_id] = o.address.external_id(theater_ids) unless o.address.nil?
      unless row[:email].nil?
        # Check if user is on the email opt-in list
        is_opted_in = members_by_email.has_key?(row[:email].downcase)

        if is_opted_in
          row[:opted_in_for_email] = 'Y'
        else
          row[:opted_in_for_email] = 'N'
          # Remove email only if user doesn't have email viewing permissions
          # AND the email is not from someone who opted in
          row[:email] = nil unless export_emails_allowed
        end
      end
      data << row
    end

    production.addresses.uniq.each do |address|
      next unless address.email.present? && members_by_email.has_key?(address.email.downcase)

      row = OrderReport.address_hash(address)
      row[:id] = 'email'
      data << row
    end

    filename = "#{Admin::ReportsHelper.safe_title(production.name)}-attendees-#{reporting_user_id}.csv"
    report_data(report_filename(filename))
  end
end
