require 'rails_helper'

RSpec.describe User, '#permission_level' do
  it 'labels administrators' do
    expect(FactoryBot.create(:admin_user).permission_level).to eq(User::ADMIN)
  end

  it 'labels box office users' do
    user = FactoryBot.create(:user, is_box_office_user: true)

    expect(user.permission_level).to eq(User::BOXOFFICE)
  end

  it 'labels users with neither flag as producers' do
    expect(FactoryBot.create(:user).permission_level).to eq(User::THEATERUSER)
  end

  # Documents the Ability precedence quirk: is_theater_user? is !admin &&
  # !box_office, so both flags set stops at `return if user.is_box_office_user?`
  # (ability.rb:121) and never reaches the admin grants. The ability assertion is
  # what makes the label provably consistent rather than merely intended to be.
  it 'reports Box Office when both flags are set, matching Ability' do
    user = FactoryBot.create(:user, is_administrator: true, is_box_office_user: true)

    expect(user.permission_level).to eq(User::BOXOFFICE)
    expect(user.ability.can?(:manage, DefaultTicketClass)).to be false
  end
end
