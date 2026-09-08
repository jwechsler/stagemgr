require 'rails_helper'

# Nightly dynamic pricing sweep: every performance of every on-sale production
# gets its allocation triggers scanned.
RSpec.describe CheckPerformanceAllocationTriggers do
  def ladder_class(production, code)
    FactoryBot.create(:ticket_class, production: production, class_code: code, class_name: code,
                                     ticket_price: 10, auto_attach: false, web_visible: true, holds_seats: true)
  end

  # A performance with LOW -> MID armed on a date trigger that is already met.
  def performance_with_due_shift(production, prefix)
    low = ladder_class(production, "#{prefix}LOW")
    mid = ladder_class(production, "#{prefix}MID")
    production.ticket_classes.reload
    performance = FactoryBot.create(:performance, production: production, performance_date: Date.current + 10.days)
    TicketClassAllocation.find_by!(performance_id: performance.id, ticket_class_id: low.id)
                         .update!(available: true, shiftable: true, shift_to_code: mid.class_code,
                                  shift_days_before_performance: 1000)
    [performance, low, mid]
  end

  def available?(performance, ticket_class)
    TicketClassAllocation.find_by!(performance_id: performance.id, ticket_class_id: ticket_class.id).available?
  end

  it 'shifts due allocations on performances of on-sale productions' do
    production = FactoryBot.create(:production, status: Production::ACTIVE, closing_at: Date.current + 30.days)
    performance, low, mid = performance_with_due_shift(production, 'JOBA')

    described_class.perform

    expect(available?(performance, low)).to be false
    expect(available?(performance, mid)).to be true
  end

  it 'leaves productions that are not on sale alone' do
    production = FactoryBot.create(:production, status: Production::INACTIVE, closing_at: Date.current + 30.days)
    performance, low, mid = performance_with_due_shift(production, 'JOBB')

    described_class.perform

    expect(available?(performance, low)).to be true
    expect(available?(performance, mid)).to be_falsy
  end
end
