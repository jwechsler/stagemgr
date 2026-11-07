require 'rails_helper'

RSpec.describe RackAttack::StaffSession do
  # Rails.cache is :null_store in the test environment, so the 60 s memo
  # cannot leak between examples; clearing it keeps that true if it changes.
  before { Rails.cache.clear }

  def request_for(session)
    env = Rack::MockRequest.env_for('/tickets/admin/theaters')
    env['rack.session'] = session unless session.nil?
    Rack::Attack::Request.new(env)
  end

  def session_for(user, token: user.persistence_token)
    { 'user_credentials_id' => user.id, 'user_credentials' => token }
  end

  def staff?(session)
    described_class.staff?(request_for(session))
  end

  it 'returns false when the request has no session' do
    expect(staff?(nil)).to be(false)
  end

  it 'returns true for an administrator' do
    expect(staff?(session_for(FactoryBot.create(:admin_user)))).to be(true)
  end

  it 'returns true for a box office user' do
    user = FactoryBot.create(:user, is_box_office_user: true)
    expect(staff?(session_for(user))).to be(true)
  end

  it 'returns false for a theater-company user who is neither administrator nor box office' do
    user = FactoryBot.create(:user, is_administrator: false, is_box_office_user: false)
    expect(staff?(session_for(user))).to be(false)
  end

  it 'returns false for an inactive administrator' do
    user = FactoryBot.create(:admin_user, status: User::INACTIVE)
    expect(staff?(session_for(user))).to be(false)
  end

  it 'returns false for the right user id with the wrong persistence token' do
    user = FactoryBot.create(:admin_user)
    expect(staff?(session_for(user, token: 'not-the-token'))).to be(false)
  end

  it 'returns false and logs a warning when the user lookup raises' do
    user = FactoryBot.create(:admin_user)
    allow(User).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished, 'db down')
    allow(Rails.logger).to receive(:warn)

    expect(staff?(session_for(user))).to be(false)
    expect(Rails.logger).to have_received(:warn).with(/\[rack-attack\] staff check failed/)
  end
end
