require 'rails_helper'

RSpec.describe Ability, 'Little Green Light sync' do
  it 'grants administrators the sync page and the customer Re-sync' do
    ability = FactoryBot.create(:admin_user).ability

    expect(ability.can?(:manage, :lgl_sync)).to be true
    expect(ability.can?(:lgl_sync, Address)).to be true
  end

  it 'does not grant box office users the sync page or the customer Re-sync' do
    ability = FactoryBot.create(:user, is_box_office_user: true).ability

    expect(ability.can?(:manage, :lgl_sync)).to be false
    expect(ability.can?(:lgl_sync, Address)).to be false
  end

  it 'does not grant theater users the sync page or the customer Re-sync' do
    ability = FactoryBot.create(:user).ability

    expect(ability.can?(:manage, :lgl_sync)).to be false
    expect(ability.can?(:lgl_sync, Address)).to be false
  end

  it 'denies anonymous users' do
    ability = Ability.new(nil)

    expect(ability.can?(:manage, :lgl_sync)).to be false
    expect(ability.can?(:lgl_sync, Address)).to be false
  end
end
