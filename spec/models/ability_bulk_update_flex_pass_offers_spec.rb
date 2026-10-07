require 'rails_helper'

RSpec.describe Ability, 'bulk_update on FlexPassOffer (Make Active / Make Inactive)' do
  it 'grants administrators bulk status changes' do
    expect(FactoryBot.create(:admin_user).ability.can?(:bulk_update, FlexPassOffer)).to be true
  end

  it 'leaves box office users editing offers one at a time' do
    ability = FactoryBot.create(:user, is_box_office_user: true).ability

    expect(ability.can?(:bulk_update, FlexPassOffer)).to be false
    expect(ability.can?(:update, FlexPassOffer)).to be true
  end
end
