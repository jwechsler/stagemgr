# Adds a named-tag collection to a model, editable as a comma-separated
# string or Tagify-style array via +tag_names=+.
#
#   include Taggable
#   has_tags :theater_tags
#
# The tag model must have a +name+ column and a belongs_to back to the
# taggable model (see TheaterTag).
module Taggable
  extend ActiveSupport::Concern

  class_methods do
    def has_tags(association_name) # rubocop:disable Naming/PredicatePrefix -- association macro, reads like has_many
      has_many association_name, inverse_of: model_name.element.to_sym,
                                 dependent: :destroy, autosave: true

      scope :tagged_with, lambda { |name|
        joins(association_name)
          .where("LOWER(#{association_name}.name) = ?", name.to_s.downcase)
          .distinct
      }

      define_method(:tags) { public_send(association_name) }
    end
  end

  def tag_names
    tags.reject(&:marked_for_destruction?).map(&:name).sort_by { |n| n.to_s.downcase }
  end

  def tag_names=(value)
    list =
      case value
      when Array  then value.map { |v| v.is_a?(Hash) ? v['value'] : v.to_s }
      when String then value.split(',')
      else []
      end

    desired = list.map { |s| s.to_s.strip }.compact_blank.uniq { |s| s.downcase }
    desired_lc = desired.map(&:downcase)

    tags.each do |tag|
      tag.mark_for_destruction unless desired_lc.include?(tag.name.to_s.downcase)
    end

    existing_lc = tags.reject(&:marked_for_destruction?).map { |t| t.name.to_s.downcase }
    desired.each do |name|
      next if existing_lc.include?(name.downcase)

      tags.build(name: name)
    end
  end
end
