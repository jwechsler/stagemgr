require 'rails_helper'

RSpec.describe ExpireStaleLogins, type: :job do
  # Timestamps are written after create: with Authlogic activated (by any spec
  # in the run) creating a record logs it in and stamps the login columns.
  def user_last_active(ago, status: User::ACTIVE)
    user = FactoryBot.create(:user, status: status)
    user.update_columns(current_login_at: ago, last_login_at: ago, last_request_at: ago)
    user
  end

  it 'deactivates accounts idle for longer than the 13 month window' do
    stale = user_last_active(13.months.ago - 1.day)
    current = user_last_active(13.months.ago + 1.day)

    expect(described_class.perform).to eq(1)

    expect(stale.reload.status).to eq(User::INACTIVE)
    expect(current.reload.status).to eq(User::ACTIVE)
  end

  it 'leaves already Inactive accounts untouched' do
    inactive = user_last_active(5.years.ago, status: User::INACTIVE)

    expect { described_class.perform }.not_to(change { inactive.reload.updated_at })
  end

  it 'is queued on the maintenance queue' do
    expect(described_class.instance_variable_get(:@queue)).to eq(:maintenance)
  end
end
