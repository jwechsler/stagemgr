require 'rails_helper'

# CurrentUser:: only checks that someone is logged in, so it must not expose
# changing or deleting theaters and productions; that is Admin:: only.
RSpec.describe 'current_user theater and production routes', type: :routing do
  it 'does not route edits or deletes of theaters' do
    expect(patch: '/current_user/theaters/1').not_to be_routable
    expect(delete: '/current_user/theaters/1').not_to be_routable
  end

  it 'does not route edits or deletes of productions' do
    expect(patch: '/current_user/theaters/1/productions/2').not_to be_routable
    expect(delete: '/current_user/theaters/1/productions/2').not_to be_routable
  end
end
