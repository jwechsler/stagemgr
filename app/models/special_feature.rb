class SpecialFeature < ApplicationRecord

  SPECIAL_FEATURE_STATUSES = (
      ACTIVE, INACTIVE = 'Active', 'Inactive'
  )

  before_destroy :reassign_feature_to_custom

  has_and_belongs_to_many :performances

  validates_presence_of :short_name, :description
  validates :short_name, :uniqueness => {:case_sensitive => false}

  def to_s
    self.short_name
  end

  def reassign_feature_to_custom
    self.performances.each { | perf| if perf.special_feature_display_markdown.blank?
                                       perf.special_feature_display_markdown = self.description
                                else
                                  perf.special_feature_display_markdown + '\n\n' + self.description
                                end
                                perf.save! }
    return true
  end

end
