require 'rails_helper'

RSpec.describe Ability, 'resend_confirmation on TicketOrder' do
  it 'grants theater users the ability to resend a confirmation' do
    user = FactoryBot.create(:user)

    expect(user.ability.can?(:resend_confirmation, TicketOrder)).to be true
  end

  it 'grants box office users the ability to resend a confirmation' do
    user = FactoryBot.create(:user, is_box_office_user: true)

    expect(user.ability.can?(:resend_confirmation, TicketOrder)).to be true
  end

  it 'grants administrators the ability to resend a confirmation' do
    expect(FactoryBot.create(:admin_user).ability.can?(:resend_confirmation, TicketOrder)).to be true
  end

  it 'does not grant theater users the neighbouring box office actions' do
    ability = FactoryBot.create(:user).ability

    expect(ability.can?(:mark_unclaimed, TicketOrder)).to be false
    expect(ability.can?(:reprint, TicketOrder)).to be false
  end

  it 'denies anonymous users' do
    expect(Ability.new(nil).can?(:resend_confirmation, TicketOrder)).to be false
  end
end
