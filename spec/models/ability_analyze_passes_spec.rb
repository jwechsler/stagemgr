require 'rails_helper'

RSpec.describe Ability, 'analyze_passes on Analysis (the Pass Sales tab)' do
  it 'grants administrators pass analysis' do
    expect(FactoryBot.create(:admin_user).ability.can?(:analyze_passes, Analysis)).to be true
  end

  it 'does not grant box office users pass analysis' do
    user = FactoryBot.create(:user, is_box_office_user: true)

    expect(user.ability.can?(:analyze_passes, Analysis)).to be false
  end

  it 'does not grant theater users pass analysis, though they may run production analyses' do
    ability = FactoryBot.create(:user).ability

    expect(ability.can?(:perform_analysis, Analysis)).to be true
    expect(ability.can?(:analyze_passes, Analysis)).to be false
  end
end
