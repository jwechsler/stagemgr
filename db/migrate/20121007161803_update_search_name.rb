class UpdateSearchName < ActiveRecord::Migration[4.2]
  def up
    Address.all.each do |a|
      a.regularize!
      a.save
    end
  end

  def down; end
end
