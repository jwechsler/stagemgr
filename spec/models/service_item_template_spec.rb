require 'rails_helper'

RSpec.describe ServiceItemTemplate, type: :model do
  it "has a unique name" do
    template = FactoryBot.create(:service_item_template, name: 'Exchange Fee')
    expect { FactoryBot.create(:service_item_template, name: 'Exchange Fee') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can initialize a service line item" do
  end
end
