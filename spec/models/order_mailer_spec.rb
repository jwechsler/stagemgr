require 'spec_helper'

describe OrderMailer do
  before (:each) do
    Authorization.ignore_access_control(true)
  end

  describe 'confirmation' do
  	let (:ticket_order) { FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash) }
  	let (:mail) { OrderMailer.ticket_confirmation(ticket_order) }

  	it 'renders the order specific subject' do
  		expect(mail.subject).to match("(.*)#{ticket_order.id}.*confirmed")
  	end

  	it 'sends to the orderer''s email' do
  		expect(mail.to).to eql([ticket_order.address.email])
  	end

  	it 'does not contain relative links' do
  		expect(mail.body).not_to match('.*href="/.*')
  	end

  end

end
