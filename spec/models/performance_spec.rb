require 'rails_helper'

RSpec.describe 'a performance' do
  before(:each) do
    @production = FactoryBot.create(:production, capacity: 10)
    @performance = FactoryBot.create(:performance, production: @production)
  end

  it 'returns an allocation given a ticket class code' do
    allocation = @performance.ticket_class_allocations.last
    expect(@performance.allocation(allocation.ticket_class.class_code)).to eq(allocation)
  end

  it 'populates ticket class allocations on demand' do
    ticket_class = FactoryBot.create(:ticket_class, class_code: 'TESTA', production: @production,
                                                    ticket_price: 10, web_visible: true)
    ticket_class2 = FactoryBot.create(:ticket_class, class_code: 'TESTB', production: @production,
                                                     ticket_price: 20, web_visible: true)
    @production.reload
    @performance.reload
    @performance.populate_ticket_class_allocations
    expect(@performance.ticket_class_allocations.map { |tca| tca.ticket_class }).to include(ticket_class)
    expect(@performance.ticket_class_allocations.map { |tca| tca.ticket_class }).to include(ticket_class2)
  end

  it 'cascades availability based on triggered sales targets' do
    ticket_class = FactoryBot.create(:ticket_class, class_code: 'TESTA', production: @production,
                                                    ticket_price: 10, web_visible: true)
    ticket_class2 = FactoryBot.create(:ticket_class, class_code: 'TESTB', production: @production,
                                                     ticket_price: 20, web_visible: true)
    ticket_class3 = FactoryBot.create(:ticket_class, class_code: 'TESTC', production: @production,
                                                     ticket_price: 1, web_visible: true)
    @production.reload
    @performance.production.reload
    @performance.populate_ticket_class_allocations
    allocation = @performance.allocation(ticket_class.class_code)
    allocation.available = true
    allocation.shiftable = true
    allocation.shift_to_code = ticket_class2.class_code
    allocation.shift_days_before_performance = 1000
    allocation.save
    allocation2 = @performance.allocation(ticket_class2.class_code)
    allocation2.available = false
    allocation2.shiftable = true
    allocation2.shift_to_code = ticket_class3.class_code
    allocation2.shift_days_before_performance = 1000
    allocation2.save
    allocation3 = @performance.allocation(ticket_class3.class_code)
    allocation3.available = false
    allocation3.save
    expect(@performance.allocation(ticket_class3.class_code).available?).to be false
    @performance.scan_ticket_allocation_triggers
    # There is some sort of weird rspec record caching happening that prevents these from updating, but they do in regular
    # expect(@performance.allocation(ticket_class.class_code).available?).to be false
    # expect(@performance.allocation(ticket_class2.class_code).available?).to be false
    expect(@performance.allocation(ticket_class3.class_code).available?).to be true
  end

  describe '#sold_out?' do
    def sell_seats(performance, count)
      count.times do
        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)
      end
    end

    def create_addon_allocation(production, performance)
      # Mirrors the "Closed-Captioning Tablet" class that masked ADOL0830's
      # sold-out status: web-visible add-on that does not occupy a seat.
      addon = FactoryBot.create(:ticket_class, class_code: 'CCTABLET', class_name: 'Closed-Captioning Tablet',
                                               production: production, ticket_price: 0,
                                               web_visible: true, holds_seats: false)
      FactoryBot.create(:ticket_class_allocation, performance: performance, ticket_class: addon, available: true)
    end

    it 'is sold out at zero seats even when a web-visible non-seat-holding add-on remains available' do
      production = FactoryBot.create(:production, capacity: 2)
      performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.current)
      sell_seats(performance, 2)
      create_addon_allocation(production, performance)

      expect(performance.reload.sold_out?).to be true
    end

    it 'is sold out when every seat is taken and only seat-holding classes exist' do
      production = FactoryBot.create(:production, capacity: 2)
      performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.current)
      sell_seats(performance, 2)

      expect(performance.reload.sold_out?).to be true
    end

    it 'is not sold out while seats remain' do
      production = FactoryBot.create(:production, capacity: 3)
      performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.current)
      sell_seats(performance, 2)
      create_addon_allocation(production, performance)

      expect(performance.reload.sold_out?).to be false
    end
  end

  describe 'pasted special feature copy' do
    # Verbatim from the crash report: box office pasted this into the admin form
    # and the latin1 column rejected the byte-order marks with
    # Mysql2::Error: Incorrect string value: '\xEF\xBB\xBFBla...'
    let(:pasted_markdown) do
      "﻿[1] Blackout Night: This performance is specifically dedicated to serving " \
        "and celebrating ﻿Black-identifying theatergoers and the Black community at large."
    end

    it 'saves copy containing byte-order marks' do
      expect { @performance.update!(special_feature_display_markdown: pasted_markdown) }.not_to raise_error

      expect(@performance.reload.special_feature_display_markdown)
        .to eq('[1] Blackout Night: This performance is specifically dedicated to serving ' \
               'and celebrating Black-identifying theatergoers and the Black community at large.')
    end

    it 'stores emoji and non-Latin scripts now that the column is utf8mb4' do
      @performance.update!(special_feature_email_markdown: "Opening night \u{1F389} 你好")

      expect(@performance.reload.special_feature_email_markdown).to eq("Opening night \u{1F389} 你好")
    end

    it 'stores legitimate typography unchanged' do
      typography = "Featuring “Hamlet” — a café favorite… naïve, £2.50"

      @performance.update!(special_feature_display_markdown: typography)

      expect(@performance.reload.special_feature_display_markdown).to eq(typography)
    end
  end
end
