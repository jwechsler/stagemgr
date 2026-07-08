class Festival < ApplicationRecord
  FESTIVAL_STATUSES = (ACTIVE, INACTIVE = 'Active', 'Inactive')

  has_many :productions, inverse_of: :festival
  has_many :flex_pass_offers, inverse_of: :festival

  has_one_attached :box_office_image
  validates :box_office_image, blob: { content_type: :image }
  validate :correct_box_office_image_mime_type

  validates :name, presence: true
  validates :status, inclusion: { in: FESTIVAL_STATUSES }
  validates :url_name, uniqueness: true, allow_blank: true,
                       format: { with: /\A[a-z0-9-]+\z/, allow_blank: true }
  validates :url_name, presence: true, if: :landing_page_enabled?

  before_validation :default_url_name_from_name

  scope :active, -> { where(status: ACTIVE) }

  def active?
    status == ACTIVE
  end

  # Always derived from the member productions — festivals carry no stored
  # dates of their own. Returns [start, end]; either may be nil.
  def date_range
    [productions.map(&:first_playing_date).min,
     productions.filter_map(&:effective_closing_at).max]
  end

  def formatted_date_range
    DateRangeDisplay.format(*date_range)
  end

  # The member shows with the soonest upcoming performances
  def featured_productions(limit = 3)
    public_productions
      .joins(:performances)
      .where(performances: { status: Performance::ACTIVE })
      .where(performances: { performance_date: Date.today.. })
      .group('productions.id')
      .reorder(Arel.sql('MIN(performances.performance_date), MIN(performances.performance_time)'))
      .limit(limit)
  end

  def public_productions
    productions.visible.sellable_to_public.order(:first_preview_at)
  end

  # Festivals can span producing companies; theaters derive from members
  def theaters
    Theater.where(id: productions.select(:theater_id).distinct).order(:name)
  end

  def now_playing?
    productions.any? { |p| p.visible? && p.now_playing? }
  end

  def to_s
    name
  end

  private

  def default_url_name_from_name
    return if url_name.present? || name.blank?

    self.url_name = name.parameterize
  end

  def correct_box_office_image_mime_type
    return unless box_office_image.attached? &&
                  !box_office_image.content_type.in?(%w[image/jpeg image/png])

    errors.add(:box_office_image, 'must be a JPEG or PNG')
  end
end
