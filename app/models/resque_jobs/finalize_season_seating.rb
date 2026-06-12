require 'csv'

class FinalizeSeasonSeating
  @queue = :maintenance
  include NotifyOnCompletion

  def self.perform(production_id, reporting_user_id = nil)
    production = Production.find(production_id)
    results = []

    production.performances.each do |perf|
      perf.orders.each do |order|
        next unless order.held? && order.paid_with_external?

        row = build_row(order, perf)
        begin
          order.transition_to!(Order::PROCESSED)
          row[:status] = order.status
          row[:error] = nil
        rescue StandardError => e
          row[:status] = order.status
          row[:error] = e.message
        end
        results << row
      end
    end

    send_report(production, results, reporting_user_id) if reporting_user_id
  end

  def self.build_row(order, perf)
    {
      order_id: order.id,
      name: order.address&.full_name,
      email: order.address&.email,
      date: perf.performance_date,
      performance_code: perf.performance_code,
      ticket_types: order.ticket_line_items.map do |tli|
        "#{tli.ticket_count}x #{tli.ticket_class.class_code}"
      end.join(', '),
      order_total: order.total,
      status: nil,
      error: nil
    }
  end

  def self.send_report(production, results, reporting_user_id)
    headers = ['Order ID', 'Name', 'Email', 'Date', 'Performance Code', 'Ticket Types', 'Order Total', 'Status',
               'Error']

    csv_string = CSV.generate do |csv|
      csv << headers
      results.each do |row|
        csv << [
          row[:order_id],
          row[:name],
          row[:email],
          row[:date],
          row[:performance_code],
          row[:ticket_types],
          row[:order_total],
          row[:status],
          row[:error]
        ]
      end
    end

    file_name = "/tmp/finalize_season_seating_#{production.production_code.downcase}_#{Date.today.strftime('%y%m%d')}.csv"
    File.write(file_name, csv_string)

    file_store = FileStore.new
    file_store.worker = FileStore::REPORT
    file_store.user_id = reporting_user_id
    file_store.notes = "Season Seating Finalization: #{production.name}"
    file_store.datafile.attach(io: File.open(file_name), filename: File.basename(file_name), content_type: 'text/csv')
    file_store.save!
    File.delete(file_name)

    notify_user_on_completion(file_store)
  end
end
