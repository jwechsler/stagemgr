class AddCompFlagToTicketClass < ActiveRecord::Migration[4.2]
  def up
    add_column :ticket_classes, :complimentary, :boolean, default: false
    add_column :default_ticket_classes, :complimentary, :boolean, default: false
    DefaultTicketClass.where('class_code in (?)', %w[COMP WITCOMP]).each do |tc|
      tc.complimentary = true
      puts "WARNING: Ticket Class #{tc.class_code} could not be updated" unless tc.save
    end
    TicketClass.where('class_code in (?)', %w[COMP WITCOMP]).each do |tc|
      tc.complimentary = true
      unless tc.save
        puts "WARNING: Ticket Class #{tc.id} - #{tc.class_code} for #{tc.production.nil? ? '(unassigned)' : tc.production.name} could not be updated"
      end
    end
  end

  def down
    remove_column :ticket_classes, :complimentary
    remove_column :default_ticket_classes, :complimentary
  end
end
