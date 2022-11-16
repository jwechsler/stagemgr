class CreateMyEmmaGroupsForTheaters < ActiveRecord::Migration[4.2]
  def up
    unless MyEmma.disabled?
      Theater.all.each {|t|
        t.create_my_emma_group
        sleep(1)
        t.save!
      }
    end
  end
end
