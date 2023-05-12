class FixMissingLastFirstNameInAddress < ActiveRecord::Migration[6.1]
  def change
    addresses = Address.where('last_first_name is null');
    addresses.each do |a|
      a.last_first_name = "#{a.last_name}#{a.first_name}#{a.middle_name}".gsub(/[\d+\s+\.!,]/,'').upcase
      a.save
    end
  end
end
