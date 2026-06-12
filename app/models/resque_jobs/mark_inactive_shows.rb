class MarkInactiveShows
  @queue = :maintenance

  def self.perform(for_date = Date.today - 9.months)
    for_date = Date.today if for_date.nil?
    productions = Production.where('status <> ? and updated_at < ? and closing_at < ?',
                                   Production::INACTIVE, for_date, for_date)
    productions.each do |prod|
      prod.status = Production::INACTIVE
      prod.save
    end
    theaters = Theater.where('status <> ? and updated_at < ?', Theater::INACTIVE, for_date)
    theaters.select do |t|
      next unless t.productions.count == t.productions.select { |p| p.inactive? }.count

      puts "#{t.name} deactivated"
      t.status = 'Inactive'
      t.save
    end
  end
end
