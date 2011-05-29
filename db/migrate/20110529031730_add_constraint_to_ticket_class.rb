class AddConstraintToTicketClass < ActiveRecord::Migration
  def self.up
    execute %{alter table ticket_classes engine = InnoDB}
    execute %{alter table line_items add constraint line_items_to_ticket_class
      foreign key (ticket_class_id) references ticket_classes(id)
    }
  end

  def self.down
    execute %{alter table line_items drop constraint line_items_to_ticket_class}
  end
end
