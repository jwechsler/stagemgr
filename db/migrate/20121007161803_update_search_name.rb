class UpdateSearchName < ActiveRecord::Migration
  def up
    Address.all.each { |a|
      a.regularize!
      a.save
    }
  end

  def down
  end
end
