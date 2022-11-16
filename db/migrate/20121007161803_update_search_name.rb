class UpdateSearchName < ActiveRecord::Migration[4.2]
  def up
    Address.all.each { |a|
      a.regularize!
      a.save
    }
  end

  def down
  end
end
