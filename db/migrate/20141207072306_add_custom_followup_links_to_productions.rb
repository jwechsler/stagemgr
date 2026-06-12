class AddCustomFollowupLinksToProductions < ActiveRecord::Migration[4.2]
  def change
    add_column :productions, :survey_link, :string
    add_column :productions, :mailing_list_link, :string
  end

  def up
    execute 'CREATE FUNCTION random() RETURNS FLOAT NO SQL SQL SECURITY INVOKER RETURN rand();'
  end

  def down
    execute 'DROP FUNCTION random();'
  end
end
