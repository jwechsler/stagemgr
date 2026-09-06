require 'rails_helper'

# Covers the genericized `standalone` layout (A6): the test env forces
# config.x.server_config['ext_site_wrapper'] = 'standalone' in
# config/environments/test.rb, so this passes regardless of the developer's
# local (gitignored) config/server.yml -- including Theater Wit's own, which
# still points ext_site_wrapper at the Foundation-compiled wrapper.
RSpec.describe 'Public layout (standalone)', type: :request do
  it 'renders a public page with the generic layout, no house branding' do
    get box_office_productions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>#{Rails.configuration.x.app_display_name}</title>")
    expect(response.body).not_to include('Theater Wit')
    expect(response.body).not_to include('Test Theater')
  end
end
