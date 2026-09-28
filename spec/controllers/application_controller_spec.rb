require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  # The global rescue_from is skipped when RAILS_RAISE_ERRORS is set (Cucumber
  # in CI); these examples only mean something when it is installed.
  before do
    skip 'global rescue_from disabled by RAILS_RAISE_ERRORS' unless described_class.rescue_handlers.any? do |klass, _|
      klass == 'StandardError'
    end
  end

  controller do
    def index
      raise 'boom'
    end
  end

  def get_with_referer(referer)
    request.env['HTTP_REFERER'] = referer
    get :index
  end

  describe 'redirect after an unhandled exception' do
    it 'returns to a same-host referer' do
      get_with_referer('http://test.host/tickets/productions')
      expect(response).to redirect_to('http://test.host/tickets/productions')
      expect(flash[:error]).to include('boom')
    end

    it 'goes to the root path instead of a foreign referer' do
      get_with_referer('https://evil.example.com/phish')
      expect(response).to redirect_to(root_path)
    end

    it 'goes to the root path when the referer is the page that failed' do
      get_with_referer('http://test.host/anonymous?page=2')
      expect(response).to redirect_to(root_path)
    end

    it 'goes to the root path when the referer is not a parseable URL' do
      get_with_referer('http://test.host/bad path|<>')
      expect(response).to redirect_to(root_path)
    end

    it 'goes to the root path when there is no referer' do
      get :index
      expect(response).to redirect_to(root_path)
    end
  end
end
