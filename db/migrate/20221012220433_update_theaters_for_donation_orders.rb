class UpdateTheatersForDonationOrders < ActiveRecord::Migration[6.1]
  def change
    donations = DonationOrder.where('theater_id is null and campaign is not null')
    donations.each do |d|
      prod = Production.find_by(name: d.campaign)
      d.theater = if prod.nil?
                    Theater.default_theater
                  else
                    prod.theater
                  end
      d.save
    end
  end
end
