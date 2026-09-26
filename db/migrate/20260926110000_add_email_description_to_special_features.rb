class AddEmailDescriptionToSpecialFeatures < ActiveRecord::Migration[6.1]
  # Canned special features get the same pair of texts as a performance's
  # custom feature: the description (web and, by default, emails) and an
  # optional markdown override used in patron emails instead.
  def change
    add_column :special_features, :email_description, :text, size: :medium
  end
end
