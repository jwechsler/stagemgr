class SpecialFeature < ApplicationRecord
  SPECIAL_FEATURE_STATUSES = (
      ACTIVE, INACTIVE = 'Active', 'Inactive'
    )

  before_destroy :reassign_feature_to_custom

  has_and_belongs_to_many :performances

  validates_presence_of :short_name, :description
  validates :short_name, :uniqueness => { :case_sensitive => false }

  def to_s
    short_name
  end

  def reassign_feature_to_custom
    performances.each { |perf|
      if perf.special_feature_display_markdown.blank?
        perf.special_feature_display_markdown = description
      else
        perf.special_feature_display_markdown + '\n\n' + description
      end
      perf.save!
    }
    true
  end
end
