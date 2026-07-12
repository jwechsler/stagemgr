require 'rails_helper'

RSpec.describe DeactivateStaleSpecialOffers, type: :job do
  it 'deactivates stale Active offers using the default one-month cutoff' do
    stale = FactoryBot.create(:percent_off_special_offer,
                              status: SpecialOffer::ACTIVE,
                              auto_expire: Date.current - 2.months)
    fresh = FactoryBot.create(:percent_off_special_offer,
                              status: SpecialOffer::ACTIVE,
                              auto_expire: Date.current + 1.week)

    described_class.perform

    expect(stale.reload.status).to eq(SpecialOffer::INACTIVE)
    expect(fresh.reload.status).to eq(SpecialOffer::ACTIVE)
  end
end
