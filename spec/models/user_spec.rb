require 'rails_helper'

RSpec.describe User, type: :model do
  # Creating a record can log it in (Authlogic session maintenance, whenever
  # another spec has activated Authlogic), which stamps the login columns. The
  # timestamps under test are therefore written after the record exists.
  def user_last_active(**timestamps)
    status = timestamps.delete(:status) || User::ACTIVE
    user = FactoryBot.create(:user, status: status)
    user.update_columns({ current_login_at: nil, last_login_at: nil, last_request_at: nil }
                          .merge(timestamps))
    user.reload
  end

  describe '#last_login_activity_at' do
    it 'is the newest of the login and request timestamps' do
      user = user_last_active(current_login_at: 3.days.ago,
                              last_login_at: 2.months.ago,
                              last_request_at: 1.day.ago)

      expect(user.last_login_activity_at).to be_within(1.second).of(user.last_request_at)
    end

    it 'ignores created_at once the account has been used' do
      user = user_last_active(last_request_at: 2.years.ago)

      expect(user.last_login_activity_at).to be_within(1.second).of(user.last_request_at)
    end

    it 'falls back to created_at when the account has never been used' do
      user = user_last_active

      expect(user.last_login_activity_at).to be_within(1.second).of(user.created_at)
    end
  end

  describe '#login_expired?' do
    it 'is true once the last activity is older than the expiration window' do
      expect(user_last_active(last_request_at: 14.months.ago).login_expired?).to be true
    end

    it 'is false inside the expiration window' do
      expect(user_last_active(last_request_at: 12.months.ago).login_expired?).to be false
    end

    it 'is false for an account that is already Inactive' do
      user = user_last_active(last_request_at: 5.years.ago, status: User::INACTIVE)

      expect(user.login_expired?).to be false
    end

    it 'uses the most recent activity even when other timestamps are stale' do
      user = user_last_active(last_login_at: 3.years.ago, current_login_at: 1.week.ago)

      expect(user.login_expired?).to be false
    end
  end

  describe '.expire_stale_logins' do
    it 'sets accounts with no activity for 13 months Inactive' do
      stale = user_last_active(last_request_at: 14.months.ago)
      recent = user_last_active(last_request_at: 2.weeks.ago)

      expect(described_class.expire_stale_logins).to eq(1)

      expect(stale.reload.status).to eq(User::INACTIVE)
      expect(recent.reload.status).to eq(User::ACTIVE)
    end

    it 'expires an account that was never logged into after 13 months' do
      never_used = user_last_active(created_at: 14.months.ago)

      described_class.expire_stale_logins

      expect(never_used.reload.status).to eq(User::INACTIVE)
    end

    it 'leaves a newly created account that has not logged in yet alone' do
      fresh = user_last_active

      described_class.expire_stale_logins

      expect(fresh.reload.status).to eq(User::ACTIVE)
    end

    it 'keeps an account whose newest timestamp is inside the window' do
      user = user_last_active(last_login_at: 3.years.ago,
                              current_login_at: 2.months.ago,
                              created_at: 4.years.ago)

      expect(described_class.expire_stale_logins).to eq(0)
      expect(user.reload.status).to eq(User::ACTIVE)
    end

    it 'leaves accounts that are already Inactive alone' do
      inactive = user_last_active(last_request_at: 5.years.ago, status: User::INACTIVE)

      expect(described_class.expire_stale_logins).to eq(0)
      expect(inactive.reload.status).to eq(User::INACTIVE)
    end

    it 'accepts an explicit cutoff' do
      user = user_last_active(last_request_at: 3.months.ago)

      described_class.expire_stale_logins(2.months.ago)

      expect(user.reload.status).to eq(User::INACTIVE)
    end

    it 'returns zero and changes nothing when every account is current' do
      user_last_active(last_request_at: 1.day.ago)

      expect(described_class.expire_stale_logins).to eq(0)
    end

    it 'does not touch accounts with no timestamps at all' do
      user = user_last_active(created_at: nil)

      expect(described_class.expire_stale_logins).to eq(0)
      expect(user.reload.status).to eq(User::ACTIVE)
    end
  end
end
