require 'rails_helper'

RSpec.describe Admin::MarkdownPreviewsController, type: :controller do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:theater_user)    { FactoryBot.create(:user) }

  describe 'as box office staff' do
    before { allow(controller).to receive(:current_user).and_return(box_office_user) }

    it 'renders the draft with the public site renderer' do
      post :create, params: { text: "**Bold** and a [link](https://example.com)\n\n- one\n- two" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<strong>Bold</strong>')
      expect(response.body).to include('<a href="https://example.com">link</a>')
      expect(response.body).to include('<li>one</li>')
    end

    it 'passes hand-written HTML through exactly as the public page does' do
      post :create, params: { text: '<b>Opening night</b> party' }

      expect(response.body).to include('<b>Opening night</b> party')
    end

    it 'leaves javascript: links as plain text, as the public renderer does' do
      post :create, params: { text: '[click](javascript:alert(1))' }

      expect(response.body).not_to include('<a')
    end

    it 'renders with the mailer renderer for the email flavor, which supports tables' do
      table = "| Seat | Row |\n|---|---|\n| 1 | A |"

      post :create, params: { text: table, flavor: 'email' }
      expect(response.body).to include('<table>')

      post :create, params: { text: table }
      expect(response.body).not_to include('<table>')
    end

    it 'renders email_site text with the site renderer, as the mail partials do' do
      post :create, params: { text: "| a |\n|---|\n| b |", flavor: 'email_site' }

      expect(response.body).not_to include('<table>')
    end

    it 'falls back to the web renderer for an unknown flavor' do
      post :create, params: { text: "| a |\n|---|\n| b |", flavor: 'bogus' }

      expect(response.body).not_to include('<table>')
    end

    it 'renders an empty body for empty text' do
      post :create, params: { text: '' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_blank
    end

    it 'refuses a draft longer than a TEXT column can hold' do
      post :create, params: { text: 'a' * (described_class::MAX_PREVIEW_LENGTH + 1) }

      expect(response).to have_http_status(:payload_too_large)
    end
  end

  describe 'as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'is not allowed' do
      post :create, params: { text: '**Bold**' }

      expect(response).to redirect_to(root_path)
    end
  end
end
