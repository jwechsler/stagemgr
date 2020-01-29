class CopyProductionMembersToMyEmmaTheatreGroup < ActiveRecord::Migration
  def up
    unless MyEmma.disabled?
      Production.all.select{|prod| !prod.myemma_attendee_group.nil? }.each do |prod|
        puts "Copying Members from #{prod.my_emma_group_name} to #{prod.theater.my_emma_group_name}"
        result = prod.copy_myemma_attendees_to_theater
        sleep(1)
        if result
          puts "   ...success"
        else
          puts "   ...failure"
        end
      end
    end
  end
  def down

  end
end
