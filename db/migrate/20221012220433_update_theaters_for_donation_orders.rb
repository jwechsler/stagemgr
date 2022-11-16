class UpdateTheatersForDonationOrders < ActiveRecord::Migration[6.1]
  def change
    donations = DonationOrder.where("theater_id is null and campaign is not null")
    donations.each { |d| prod = Production.find_by(name: d.campaign)
      if prod.nil?
        d.theater = Theater.default_theater
      else
        d.theater = prod.theater
      end
      d.save
    }
  end
end
