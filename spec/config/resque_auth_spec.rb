require 'rails_helper'

# ResqueAuth is defined in config/initializers/resque_auth.rb, which has already
# run by the time any spec loads. /admin/resque is mounted with no other
# authentication in front of it (config/routes.rb), so what this installs is the
# only thing standing between the internet and the queue dashboard.
RSpec.describe ResqueAuth do
  let(:server) { class_double(Resque::Server, use: true) }

  # Rack::Auth::Basic's block receives the submitted user and password.
  def authenticator
    block = nil
    allow(server).to receive(:use) { |_middleware, &given| block = given }
    yield
    block
  end

  describe '.install' do
    it 'installs basic auth that accepts the configured password' do
      check = authenticator { described_class.install(server, password: 'letmein', production: false) }

      expect(check.call('admin', 'letmein')).to be(true)
      expect(check.call('admin', 'wrong')).to be(false)
      expect(check.call('admin', nil)).to be(false)
    end

    it 'reports what it installed' do
      expect(described_class.install(server, password: 'letmein', production: false)).to eq(:password)
      expect(server).to have_received(:use).with(Rack::Auth::Basic)
    end

    # Fail closed: an open dashboard leaks job arguments (order ids, patron
    # email addresses) and offers a one-click "clear failed jobs".
    it 'denies everyone in production when no password is configured' do
      allow(Kernel).to receive(:warn)
      check = authenticator { described_class.install(server, password: nil, production: true) }

      expect(check.call('admin', 'anything')).to be(false)
      expect(check.call(nil, nil)).to be(false)
    end

    it 'says loudly why production is denying the dashboard' do
      allow(Kernel).to receive(:warn)
      allow(Rails.logger).to receive(:warn)

      expect(described_class.install(server, password: nil, production: true)).to eq(:denied)
      expect(Kernel).to have_received(:warn).with(/RESQUE_ADMIN_PASSWORD/)
      expect(Rails.logger).to have_received(:warn).with(/DENIED/)
    end

    # Unchanged from before this branch: a developer who never set a password
    # can still open the dashboard on their laptop.
    it 'leaves the dashboard open outside production when no password is configured' do
      expect(described_class.install(server, password: nil, production: false)).to eq(:open)
      expect(server).not_to have_received(:use)
    end
  end
end
