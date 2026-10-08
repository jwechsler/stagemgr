require 'rails_helper'

# CanCan::AccessDenied is expected traffic (expired sessions, hidden offers),
# not a crash: it must reach a rescue_from that redirects, never the
# StandardError handler that mails ExceptionNotifier.
RSpec.describe 'CanCan::AccessDenied routing' do
  before { allow(ExceptionNotifier).to receive(:notify_exception) }

  describe ApplicationController, type: :controller do
    controller(ApplicationController) do
      def index
        raise CanCan::AccessDenied, 'Not yours'
      end

      def show
        raise ArgumentError, 'boom'
      end
    end

    it 'redirects a public denial to the root without notifying' do
      get :index

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('Not yours')
      expect(ExceptionNotifier).not_to have_received(:notify_exception)
    end

    it 'still notifies for an unexpected error' do
      routes.draw { get 'show' => 'anonymous#show' }
      get :show

      expect(ExceptionNotifier).to have_received(:notify_exception)
    end
  end

  describe Admin::MembershipsController, type: :controller do
    it 'sends an anonymous user to the login page without notifying' do
      allow(controller).to receive(:current_user).and_return(nil)
      get :index

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include('session has expired')
      expect(ExceptionNotifier).not_to have_received(:notify_exception)
    end
  end

  it 'gives every admin controller the admin AccessDenied handler' do
    Rails.autoloaders.main.eager_load_dir(Rails.root.join('app/controllers/admin').to_s)
    strays = ApplicationController.descendants
                                  .select { |klass| klass.name&.start_with?('Admin::') }
                                  .reject { |klass| klass <= Admin::ApplicationController }

    expect(strays.map(&:name)).to be_empty
  end
end
