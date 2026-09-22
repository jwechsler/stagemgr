require 'rails_helper'

RSpec.describe OrderDecorator do
  describe '#description_with_placed_date' do
    it 'appends a ", placed MM/DD" suffix to the description' do
      order = FactoryBot.create(:ticket_order, created_at: Time.current)

      text = order.decorate.description_with_placed_date

      expect(text).to eq("#{order.decorate.description}, placed #{order.created_at.strftime('%m/%d')}")
    end
  end
end
