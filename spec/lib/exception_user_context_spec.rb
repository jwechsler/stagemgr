require 'rails_helper'

RSpec.describe ExceptionUserContext do
  def env_for(session)
    env = Rack::MockRequest.env_for('/admin/productions', 'HTTP_HOST' => 'stagemgr.test')
    env['rack.session'] = session if session
    env
  end

  # Authlogic stores the id as a String in the session.
  def session_for(user, token: nil)
    { 'user_credentials' => token || user.persistence_token,
      'user_credentials_id' => user.id.to_s }
  end

  def value_for(context, label)
    context.fields.select { |l, _v| l == label }.map(&:last)
  end

  # The constants are hardcoded so the class works when the database is down.
  # This is what keeps them honest if Authlogic's defaults ever change.
  it 'keeps its session keys in step with Authlogic' do
    expect(described_class::SESSION_TOKEN_KEY).to eq(UserSession.session_key.to_s)
    expect(described_class::SESSION_USER_ID_KEY).to eq("#{UserSession.session_key}_#{User.primary_key}")
  end

  describe 'with no signed-in user' do
    it 'reports anonymous for a nil env' do
      expect(value_for(described_class.from_env(nil), 'Permission')).to eq([described_class::ANONYMOUS])
    end

    it 'reports anonymous when the env carries no session' do
      expect(value_for(described_class.from_env(env_for(nil)), 'Permission')).to eq([described_class::ANONYMOUS])
    end

    it 'reports anonymous without querying for a session that has no user id' do
      expect(User).not_to receive(:find_by)

      context = described_class.from_env(env_for({}))

      expect(value_for(context, 'Permission')).to eq([described_class::ANONYMOUS])
      expect(context.user).to be_nil
    end
  end

  describe 'with a signed-in user' do
    it 'reports an administrator' do
      user = FactoryBot.create(:admin_user)

      context = described_class.from_env(env_for(session_for(user)))

      expect(context.email).to eq(user.email)
      expect(value_for(context, 'Email')).to eq([user.email])
      expect(value_for(context, 'Permission')).to eq([User::ADMIN])
      expect(value_for(context, 'Note')).to be_empty
    end

    it 'reports a box office user' do
      user = FactoryBot.create(:user, is_box_office_user: true)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Permission')).to eq([User::BOXOFFICE])
    end

    it 'names the theaters a producer is scoped to' do
      user = FactoryBot.create(:user)
      user.theaters << FactoryBot.create(:theater, name: 'Zed Theater')
      user.theaters << FactoryBot.create(:theater, name: 'Apex Theater')

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Permission')).to eq([User::THEATERUSER])
      expect(value_for(context, 'Theaters')).to eq(['Apex Theater, Zed Theater'])
    end

    it 'flags a producer with no theaters assigned' do
      context = described_class.from_env(env_for(session_for(FactoryBot.create(:user))))

      expect(value_for(context, 'Theaters')).to eq(['(none assigned)'])
    end

    it 'marks a resident producer, whose Ability grants differ' do
      user = FactoryBot.create(:user)
      user.theaters << FactoryBot.create(:theater, theater_class: Theater::RESIDENT)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Permission')).to eq(["#{User::THEATERUSER} (resident)"])
    end

    # Ability lets box office shadow administrator; surface it where a permission
    # bug would be diagnosed.
    it 'calls out a user carrying both permission flags' do
      user = FactoryBot.create(:user, is_administrator: true, is_box_office_user: true)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Permission')).to eq(["#{User::BOXOFFICE} -- also flagged Administrator"])
    end

    it 'reports a non-active status' do
      user = FactoryBot.create(:user, status: User::INACTIVE)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Status')).to eq([User::INACTIVE])
    end
  end

  describe 'when the session does not actually authenticate' do
    it 'identifies the user but warns that the persistence token is stale' do
      user = FactoryBot.create(:admin_user)

      context = described_class.from_env(env_for(session_for(user, token: 'stale-token')))

      expect(value_for(context, 'Email')).to eq([user.email])
      expect(value_for(context, 'Note').join).to include('NOT authenticated')
    end

    it 'warns when the session had timed out' do
      user = FactoryBot.create(:admin_user)
      user.update_column(:last_request_at, 7.hours.ago)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Note').join).to include('timed out')
    end

    it 'does not claim a timeout when the user has never made a tracked request' do
      user = FactoryBot.create(:admin_user)
      user.update_column(:last_request_at, nil)

      context = described_class.from_env(env_for(session_for(user)))

      expect(value_for(context, 'Note')).to be_empty
    end

    it 'reports a session id with no matching user' do
      user = FactoryBot.create(:admin_user)
      session = session_for(user)
      user.destroy

      context = described_class.from_env(env_for(session))

      expect(value_for(context, 'Session user id')).to eq([user.id.to_s])
      expect(value_for(context, 'Note').join).to include('stale or forged session cookie')
    end
  end

  # The whole reason the session id is emitted before the query: when the
  # database is what broke, the raw id is still all we need to name the actor.
  it 'still reports the session id when the user lookup itself fails' do
    user = FactoryBot.create(:admin_user)
    allow(User).to receive(:find_by).and_raise(ActiveRecord::StatementInvalid, 'MySQL server has gone away')

    context = described_class.from_env(env_for(session_for(user)))

    expect(value_for(context, 'Session user id')).to eq([user.id.to_s])
    expect(value_for(context, 'Note').join).to include('MySQL server has gone away')
  end
end
