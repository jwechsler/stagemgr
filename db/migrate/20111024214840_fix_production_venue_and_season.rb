class FixProductionVenueAndSeason < ActiveRecord::Migration
  def self.up
    Production.all.each { |p|
      unless p.opening_at.nil?
        opening_year = p.opening_at.year
        opening_month = p.opening_at.month
        if opening_month >= 9
          p.season = (opening_year+1).to_s
        else
          p.season = (opening_year).to_s
        end
        p.venue = Venue.first if p.venue.nil?
        p.theater = p.performance.production.theater if p.theater.nil?
        p.save!
      end
    }
  end

  def self.down
  end
end
