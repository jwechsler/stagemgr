class SpecialFeature < ApplicationRecord
  include TextSanitizable

  SPECIAL_FEATURE_STATUSES = (
      ACTIVE, INACTIVE = 'Active', 'Inactive'
    )

  before_validation :scrub_string_attributes
  before_destroy :reassign_feature_to_custom

  has_and_belongs_to_many :performances

  def active?
    status == ACTIVE
  end

  validates :short_name, :description, presence: true
  validates :short_name, :uniqueness => { :case_sensitive => false }

  def to_s
    short_name
  end

  # What patron emails show for this feature: the Custom Email text when set,
  # otherwise the description -- the same rule a performance's Custom Email
  # follows over its Custom Special Feature text.
  def email_text
    email_description.presence || description
  end

  # Deleting a feature folds its texts into each performance's custom feature
  # fields, so the performance keeps saying the same thing on the web and in
  # emails. A performance's Custom Email replaces its custom display text in
  # emails, so once either side has email text the email field must carry the
  # whole email version: its existing text (or the display text it was
  # standing in for) plus this feature's email text.
  def reassign_feature_to_custom
    performances.each do |perf|
      display = perf.special_feature_display_markdown
      if email_description.present? || perf.special_feature_email_markdown.present?
        email_base = perf.special_feature_email_markdown.presence || display
        perf.special_feature_email_markdown = append_markdown(email_base, email_text)
      end
      perf.special_feature_display_markdown = append_markdown(display, description)
      perf.save!
    end
    true
  end

  private

  def append_markdown(existing, addition)
    [existing.presence, addition].compact.join("\n\n")
  end
end
