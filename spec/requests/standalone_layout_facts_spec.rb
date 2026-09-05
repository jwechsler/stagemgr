require 'rails_helper'

# The standalone layout's footer is the only chrome a public page has, so it
# carries the house's contact facts -- and must still read correctly for a house
# that has configured none of them (see spec/requests/public_layout_spec.rb for
# the layout's identity, and spec/views/shared/house_facts_omitted_spec.rb for
# the same guards inside the pages).
RSpec.describe 'Standalone layout footer', type: :request do
  it 'prints the configured address and phone beside the copyright' do
    get box_office_productions_path

    expect(response.body).to include('1 EXAMPLE ST, TESTCITY, IL 60657 · 555-BOX-OFFICE')
  end

  it 'prints the copyright alone when the house has configured no facts' do
    unconfigured = TheaterInfo.new(server_config: {}, email_addresses: {})
    allow(TheaterInfo).to receive(:new).and_return(unconfigured)

    get box_office_productions_path

    expect(response.body).to include("&copy; #{Date.current.year} #{unconfigured.name}")
    expect(response.body).not_to include('·')
    expect(response.body).not_to include('1 EXAMPLE ST')
  end
end
