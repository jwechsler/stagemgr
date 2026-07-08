class ProductionAttendeeReport < OrderReport
  attr_reader :productions, :export_emails_allowed

  # production_ids may be a single id (legacy queued scalar jobs) or an array.
  def initialize(production_ids, export_emails_allowed = false, reporting_user_id = nil)
    # LEGACY-COMPAT: Array() keeps previously-enqueued scalar Resque jobs
    # (single production_id) working alongside the new multi-production form.
    @productions = Production.where(id: Array(production_ids))
    @export_emails_allowed = export_emails_allowed
    keys = OrderReport.columns_for_orders(true, true) +
           %i[order_total order_revenue num_tickets num_seats external_id
              opted_in_for_email marketing_source]

    keys += [:seat_assignments] if @productions.any?(&:has_reserved_seating?)
    super(keys, reporting_user_id)
    @data = []
  end

  # create
  #
  # builds a large export of orders across the selected productions with
  # contact info, order totals, and email opt-in status.
  #
  # @return array [keys, value hashed by key] for each order

  def create
    members_by_email = Admin::ReportsHelper.attendees_on_email_list_for_productions(@productions)

    theater_ids = User.find(reporting_user_id).theater_ids
    production_ids = @productions.map(&:id)

    TicketOrder.settled.joins(:performance)
               .includes(:ticket_line_items, :payments, :address)
               .where(performances: { production_id: production_ids })
               .find_each(batch_size: 1000) do |o| # Adjust batch_size as needed
      row = OrderReport.create_hash_from_order_fields(o)
      row[:marketing_source] = o.marketing_source
      row[:external_id] = o.address.external_id(theater_ids) unless o.address.nil?
      unless row[:email].nil?
        # Check if user is on the email opt-in list
        is_opted_in = members_by_email.key?(row[:email].downcase)

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

    # Opted-in attendees, deduped by email across every selected production.
    seen_opt_in_emails = {}
    @productions.each do |production|
      production.addresses.uniq.each do |address|
        next unless address.email.present? && members_by_email.key?(address.email.downcase)

        email_key = address.email.downcase
        next if seen_opt_in_emails[email_key]

        seen_opt_in_emails[email_key] = true
        row = OrderReport.address_hash(address)
        row[:id] = 'email'
        data << row
      end
    end

    report_data(report_filename(export_filename))
  end

  private

  # Single production keeps its historical filename; multiple productions use
  # the shared festival name when they all belong to one festival, else a
  # generic label.
  def export_filename
    "#{Admin::ReportsHelper.safe_title(export_title)}-attendees-#{reporting_user_id}.csv"
  end

  def export_title
    return @productions.first.name if @productions.one?

    festival_ids = @productions.map(&:festival_id).uniq
    if festival_ids.length == 1 && festival_ids.first.present?
      Festival.find(festival_ids.first).name
    else
      'selected-productions'
    end
  end
end
