# Shared context that mocks PrintingService.print_order to synchronously
# mark the order as FULFILLED, simulating PrintBatchJob completing successfully.
#
# Include this in specs that exercise transition_to!(Order::FULFILLED) and
# need the attendance-tracking callbacks to fire as they would after a real
# successful print job.
RSpec.shared_context 'auto-fulfilling print service' do
  before do
    allow(PrintingService).to receive(:print_order) do |order_id, **_opts|
      batch_id = "INDIVIDUAL_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
      order = TicketOrder.find(order_id)
      order.status = Order::FULFILLED
      order.save!
      batch_id
    end
  end
end
