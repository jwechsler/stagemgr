require 'rails_helper'

RSpec.describe UserSession, type: :model do
  before { activate_authlogic }

  # With Authlogic activated, creating a record logs it in and stamps the login
  # columns, so the timestamps under test are written afterwards.
  def user_last_active(ago, status: User::ACTIVE)
    user = FactoryBot.create(:user, status: status)
    user.update_columns(current_login_at: ago, last_login_at: ago, last_request_at: ago)
    user
  end

  def login(user)
    UserSession.new(email: user.email, password: 'password')
  end

  it 'logs in an account with recent activity' do
    expect(login(user_last_active(1.week.ago)).save).to be true
  end

  it 'refuses an account that is already Inactive' do
    session = login(user_last_active(1.week.ago, status: User::INACTIVE))

    expect(session.save).to be_falsey
    expect(session.errors[:login].join).to include('currently inactive')
  end

  it 'deactivates and refuses an account whose login has expired' do
    user = user_last_active(14.months.ago)
    session = login(user)

    expect(session.save).to be_falsey
    expect(session.errors[:login].join).to include('deactivated after 13 months')
    expect(user.reload.status).to eq(User::INACTIVE)
  end

  it 'does not report an expired account as merely inactive' do
    session = login(user_last_active(14.months.ago))
    session.save

    expect(session.errors[:login].join).not_to include('currently inactive')
  end

  it 'leaves an account inside the window Active' do
    user = user_last_active(12.months.ago)
    login(user).save

    expect(user.reload.status).to eq(User::ACTIVE)
  end

  it 'does not deactivate a dormant account when its password is reset' do
    user = user_last_active(14.months.ago)

    user.update!(password: 'newpassword')

    expect(user.reload.status).to eq(User::ACTIVE)
  end
end
