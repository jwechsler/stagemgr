require 'rails_helper'

RSpec.describe 'a production' do
  context 'with one order' do
    include_context 'auto-fulfilling print service'

    before(:each) do
      @ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    end

    it 'should have one attendee when fulfilled' do
      expect(@ticket_order.performance.production.addresses.count).to eq(0)
      @ticket_order.transition_to!(Order::FULFILLED)
      expect(@ticket_order.performance.production.addresses.count).to eq(1)
    end
    it 'can override the email links for surveys and mailing list solicitation' do
      mail = OrderMailer.standard_followup(@ticket_order)
      expect(mail.body.encoded).to match('SURVEYLINK.TEST')
      expect(mail.body.encoded).to match('MAILINGLINK.TEST')
      @ticket_order.performance.production.survey_link = 'http://newsurvey.test'
      @ticket_order.performance.production.mailing_list_link = 'http://newmailing.test'
      @ticket_order.performance.production.save!
      mail = OrderMailer.standard_followup(@ticket_order)
      expect(mail.body.encoded).to match('newsurvey.test')
      expect(mail.body.encoded).to match('newmailing.test')
    end
  end

  it 'always stores custom label as lowercase' do
    @production = FactoryBot.create(:production)
    @production.custom_label = 'BiGLabel'
    @production.save
    expect(@production.custom_label).to eq('biglabel')
  end

  context 'capacity logic' do
    it 'returns the database capacity when no seat map is assigned' do
      production = FactoryBot.create(:production, capacity: 150)
      expect(production.capacity).to eq(150)
    end

    it 'returns seat map capacity when seat map is assigned' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 75)
      production = FactoryBot.create(:production, capacity: 150, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      expect(production.capacity).to eq(75)
      expect(production.capacity).not_to eq(150)
    end

    it 'returns 0 when seat map has no seats' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 0)
      production = FactoryBot.create(:production, capacity: 150, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      expect(production.capacity).to eq(0)
    end

    it 'prioritizes seat map capacity over database capacity' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 25)
      production = FactoryBot.create(:production, capacity: 200, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      expect(production.capacity).to eq(25)
      expect(production.read_attribute(:capacity)).to eq(200)
    end

    it 'handles nil seat map gracefully' do
      production = FactoryBot.create(:production, capacity: 100)
      production.seat_map = nil

      expect(production.capacity).to eq(100)
    end
  end
end
