class AddConfirmationMessageToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :confirmation_message, :text
    add_column :productions, :follow_up_message_2, :text
  end

  def self.down
    remove_column :productions, :follow_up_message_2
    remove_column :productions, :confirmation_message
  end
end
