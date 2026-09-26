class Performance < ApplicationRecord
  include TextSanitizable

  PERFORMANCE_STATUSES = (ACTIVE, INACTIVE, PRIVATE = 'Active', 'Inactive', 'Private')

  # Marks a calendar footnote key as carrying custom special-feature copy rather
  # than naming a SpecialFeature by short_name. See #custom_footnote_key.
  CUSTOM_FOOTNOTE_PREFIX = '_custom'.freeze

  belongs_to               :production, inverse_of: :performances
  has_many                 :special_offers, inverse_of: :performance
  has_many                 :ticket_class_allocations, -> { includes :ticket_class }, inverse_of: :performance
  has_many                 :ticket_classes, :through => :ticket_class_allocations, inverse_of: :performances
  has_many                 :seat_assignments, -> { includes :seat }, inverse_of: :performance
  has_many                 :seats, :through => :seat_assignments
  has_one                  :seat_map, :through => :production
  has_many                 :orders, :class_name => 'TicketOrder', inverse_of: :performance
  has_many                 :broadcasts, class_name: 'PerformanceBroadcast', dependent: :destroy
  has_many                 :payment_restrictions, :dependent => :destroy, inverse_of: :performance
  has_many                 :restricted_payment_types, :source => :payment_type, :through => :payment_restrictions
  has_and_belongs_to_many  :special_features
  has_one                  :house_count, dependent: :destroy

  default_scope            { includes(:ticket_class_allocations) }

  scope                    :sellable, -> { where(status: Performance.sellable_statuses) }

  validates   :status, inclusion: { :in => PERFORMANCE_STATUSES }
  validates  :performance_code, uniqueness: true
  validates  :performance_time, uniqueness: { :scope => [:performance_date, :production_id] }
  validates_each           :performance_time do |record, attr, _value|
    if !record.production.nil? && record.production.performances.any? do |p|
      p.id != record.id &&
      p.performance_date == record.performance_date &&
      p.performance_time.hour == record.performance_time.hour &&
      p.performance_time.min == record.performance_time.min
    end
      record.errors.add(attr, 'has already been taken')
    end
  end
  validates           :performance_code, presence: true
  validates           :performance_date, presence: true
  validates           :performance_time, presence: true
  validates           :production, presence: true

  before_validation               :clean_values
  before_validation               :populate_ticket_class_allocations, :unless => proc { |p| p.production.nil? }
  before_validation               :performance_code_must_match_production, :unless => proc { |p| p.production.nil? }
  before_save                     :manage_seat_inventory, :unless => proc { |p|
    p.production.nil? || p.production.seat_map.nil?
  }
  before_destroy                  :protect_performances_with_orders
  after_create                    :create_metrics
  after_save                      :propagate_requested_allocation_availability
  accepts_nested_attributes_for   :ticket_class_allocations

  def number_of_seats_left(exclude_order = nil)
    production.capacity - seats_held(exclude_order)
    # self.orders.select{|o| o.holding_seats? }.inject(0){|sum,order| sum + order.ticket_line_items.sum(:ticket_count) }
  end

  # Seat-inventory vocabulary facades (preferred names).
  #
  # These are LIVE figures computed from the orders table on demand. Contrast
  # with HouseCount, which stores a CACHED snapshot of the same numbers and is
  # only refreshed when CalculateHouseCountsJob runs.
  #
  # seats_occupied counts every seat that is currently spoken for -- holds,
  # in-progress checkouts, sold tickets, exchanges, releases (Order's
  # SEAT_OCCUPYING_STATUSES). It is deliberately broader than "seats on hold",
  # which would be just the box-office HOLD status. seats_occupied is an exact
  # alias of the original #seats_held; seats_available aliases
  # #number_of_seats_left (capacity minus occupied seats). The optional
  # exclude_order argument (used during exchanges to ignore the order being
  # edited) is forwarded unchanged.
  def seats_occupied(exclude_order = nil)
    seats_held(exclude_order)
  end

  def seats_available(exclude_order = nil)
    number_of_seats_left(exclude_order)
  end

  def seats_held(exclude_order = nil)
    TicketLineItem.where('ticket_classes.holds_seats = ? and orders.status in (?) and orders.performance_id = ? and order_id != ?',
                         true,
                         Order::HOLDING_SEAT_STATUSES,
                         id,
                         (exclude_order.nil? ? 0 : exclude_order.id)).includes(:order, :ticket_class).sum(:ticket_count)
  end

  # Dynamic pricing: promote every available, shiftable allocation whose
  # trigger is met to its shift_to_code tier (source off, target on), repeating
  # while anything moved so a ladder can cascade A -> B -> C in one pass.
  # Strictly forward: nothing here ever re-enables a source tier; the only
  # "backward" path is Performance#reset_shift_ladder_from! (propagation).
  # Runs from the nightly CheckPerformanceAllocationTriggers job and, since the
  # propagate toggle learned to reset ladders, right after a performance saves.
  def scan_ticket_allocation_triggers
    max_scans = 15
    scan_required = true # we need to rescan if any performance allocation has shifted in case it cascades up
    while scan_required && max_scans > 0
      new_scan = false
      max_scans -= 1
      # Callers may have written allocation rows through other objects (the
      # propagate path saves a separately loaded target); start from the DB.
      ticket_class_allocations.reload
      seats_currently_held = seats_held
      ticket_class_allocations.select { |tca| tca.shiftable? && tca.available? }.each do |tca|
        next unless tca.trigger_satisfied?(seats_currently_held)

        allocation = self.allocation(tca.shift_to_code)
        if allocation.nil?
          # A stale or mistyped target (or a class added after this performance's
          # rows were populated). Skip rather than abort the whole scan run.
          Rails.logger.warn("Cannot promote #{performance_code}, ticket class #{tca.ticket_class.class_code}: " \
                            "no allocation for shift_to_code #{tca.shift_to_code}")
          next
        end
        Rails.logger.info("Promoting #{performance_code}, ticket class #{tca.ticket_class.class_code} " \
                          "to #{tca.shift_to_code}")
        tca.available = false
        allocation.available = true
        if allocation.save && tca.save
          new_scan = true
        else
          Rails.logger.warn("Promotion of #{performance_code}, ticket class #{tca.ticket_class.class_code} did not save: " \
                            "#{(allocation.errors.full_messages + tca.errors.full_messages).join('; ')}")
        end
      end
      scan_required = new_scan
    end
  end

  def number_of_tickets_left
    number_of_seats_left
  end

  # Zero seats means sold out, full stop. A 2020-era escape clause kept this
  # false while any available web-visible non-seat-holding allocation existed
  # (for remote-streaming tickets), but add-on classes like the closed-captioning
  # tablet satisfied it too, leaving sold-out houses labeled "Limited seats
  # remaining" on the calendar. Do not reintroduce it; if standalone non-seat
  # products return, they need their own flag on TicketClass.
  def sold_out?
    number_of_seats_left <= 0
  end

  def happening_soon?
    at = performance_at
    # .to_i so a missing/nil config key degrades to 0 instead of raising NoMethodError
    # on nil (mirrors the coercion on restrict_sales_due_to_capacity_at in near_capacity?).
    (Time.now < at + production.running_time.minutes) && (Time.now + Rails.configuration.x.server_config['restrict_sales_due_to_time_at_minutes_before'].to_i.minutes > at)
  end

  # Curtain as an instant in the app time zone. performance_time is a bare
  # time-of-day, so it is rendered in Time.zone and re-parsed there rather than
  # in the process's system zone, which differs from Central on a CI runner.
  def performance_at
    Time.zone.parse("#{performance_date} #{curtain_hour_min}")
  end

  delegate :to_datetime, to: :performance_at

  def curtain_hour_min
    performance_time.in_time_zone.strftime('%H:%M')
  end

  def to_time_with_zone
    Time.zone.parse("#{performance_date}T#{performance_time.strftime("%H:%M:00")}")
  end

  def near_capacity?
    number_of_seats_left <= Rails.configuration.x.server_config['restrict_sales_due_to_capacity_at'].to_i
  end

  # Calendar-optimized methods using pre-computed HouseCount data.
  # Fall back to live queries when HouseCount is not yet available.
  # Do NOT use these for order processing — use the live methods instead.

  def calendar_sold_out?
    house_count&.persisted? ? house_count.sold_out? : sold_out?
  end

  def calendar_near_capacity?
    house_count&.persisted? ? house_count.near_capacity? : near_capacity?
  end

  def calendar_seats_left
    house_count&.persisted? ? house_count.available_seats : number_of_seats_left
  end

  def calendar_heatmap_level
    return nil if performance_at + production.running_time.minutes < Time.now
    return nil if calendar_sold_out? || withhold_from_public?

    capacity = production.capacity
    return nil if capacity.nil? || capacity <= 0

    seats_left = calendar_seats_left
    pct_remaining = (seats_left.to_f / capacity) * 100
    thresholds = Rails.configuration.x.server_config['calendar_display'] || {}
    if pct_remaining <= (thresholds['critical_at'] || 30)
      'critical'
    elsif pct_remaining <= (thresholds['warning_at'] || 50)
      'warning'
    end
  end

  def populate_ticket_class_allocations
    (production.ticket_classes - ticket_class_allocations.map do |tca|
      tca.ticket_class
    end).each do |ticket_class|
      ticket_class_allocations.build({ :ticket_class => ticket_class, :available => ticket_class.auto_attach,
                                       :performance => self })
    end
    ticket_class_allocations.each do |tca|
      tca.available = true if tca.ticket_class.auto_attach?
    end
  end

  # The allocation row settings the propagate toggle copies forward: the
  # availability itself plus the limit and the dynamic-pricing trigger fields
  # (Trigger?, To Code, At %, Days Before) -- the whole row as staff see it.
  PROPAGATED_ALLOCATION_ATTRIBUTES = %w[available ticket_limit shiftable shift_to_code
                                        shift_when_capacity_over shift_days_before_performance].freeze

  # Applies the allocation grid's "propagate to all later performances" toggle
  # (TicketClassAllocation#propagate_available, a form-only flag). Runs
  # after_save so nothing propagates unless this performance actually saved,
  # and inside the save transaction so a failure rolls everything back.
  #
  # "Later" is anchored to THIS performance's date/time, not the current date:
  # editing a mid-run performance applies the row from that point in the run
  # onward, leaving earlier performances alone.
  #
  # The row is fanned out as-is, on OR off: the toggle is how staff switch a
  # class off for the rest of a run as well as on. Afterwards this performance
  # gets the same reset-and-replay as the later ones: every ladder whose head
  # row staff re-armed in this save (edited, or toggle armed, and left
  # available) is switched off below the head -- except rows staff explicitly
  # checked or unchecked in the same save, which the form settles -- and then
  # its dynamic pricing scan re-runs, so the edited performance and the ones it
  # propagated to follow the same rule immediately instead of waiting for the
  # nightly job.
  def propagate_requested_allocation_availability
    sources = ticket_class_allocations.select(&:propagate_available?)
    propagate_allocation_settings!(sources) if sources.any?
    sources.each { |tca| tca.propagate_available = nil } # one-shot: don't re-fire on a later save
    rearmed = (sources + edited_allocation_rows).uniq
    return if rearmed.empty?

    rearmed.select(&:available?).each { |head| reset_shift_ladder_from!(head) }
    # Last: the scan reloads the association, discarding the one-shot flags.
    scan_ticket_allocation_triggers
  end

  # Existing allocation rows whose availability, limit or trigger settings this
  # save changed -- i.e. staff edited the grid. Rows that
  # populate_ticket_class_allocations just created do not count, so unrelated
  # bulk saves (renumbering performance codes, reassigning special features)
  # never run the dynamic pricing scan as a side effect.
  def edited_allocation_rows
    ticket_class_allocations.select do |tca|
      !tca.previously_new_record? && tca.saved_changes.keys.intersect?(PROPAGATED_ALLOCATION_ATTRIBUTES)
    end
  end

  # Copies each armed source row's settings onto every later performance's
  # allocation for the same class, overwriting what is there -- an
  # already-available allocation with a stale limit or trigger still gets the
  # row's values, so the rest of the run ends up uniform.
  #
  # Reset and replay: a later performance may already have shifted a class up
  # its dynamic pricing ladder (row off, its shift_to_code tier on). Per later
  # performance, every armed row's ladder is walked from its OLD links and
  # switched off, then ALL the rows land, then that performance's triggers are
  # re-run once against its own sales and date -- so a changed threshold or
  # target yields exactly the tier the new rule says, and rows armed together
  # cannot undo each other (landing MID off after LOW's scan promoted to MID).
  #
  # A row that cannot be saved on a later performance is reported on this
  # performance (the save returns false with the message) instead of vanishing:
  # ActiveRecord::Base#save turns a RecordInvalid raised in after_save into a
  # bare false, which the admin form would render with no error at all.
  def propagate_allocation_settings!(source_allocations)
    copies = source_allocations.map do |source|
      [source.ticket_class_id, source.attributes.slice(*PROPAGATED_ALLOCATION_ATTRIBUTES)]
    end
    later_performances_in_run.each do |perf|
      perf.apply_propagated_allocations!(copies)
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, "Could not apply the ticket class settings to #{perf.performance_code}: #{e.message}")
      raise
    end
  end

  # One later performance's share of the fan-out: reset, land, scan. `copies`
  # is [[ticket_class_id, attributes], ...]. Rows are found or built through
  # this performance's own association so the walk, the landing and the scan
  # all see the same objects.
  def apply_propagated_allocations!(copies)
    targets = copies.map do |ticket_class_id, copied|
      target = ticket_class_allocations.detect { |tca| tca.ticket_class_id == ticket_class_id } ||
               ticket_class_allocations.build(ticket_class_id: ticket_class_id)
      [target, copied]
    end
    # Every reset before any landing: a landed row's new links must not steer
    # another row's walk.
    existing_heads = targets.map(&:first).reject(&:new_record?)
    existing_heads.each { |head| reset_shift_ladder_from!(head) }
    targets.each do |target, copied|
      target.attributes = copied
      target.save! if target.new_record? || target.changed?
    end
    scan_ticket_allocation_triggers
  end

  # Switches off every tier this performance's dynamic pricing could have
  # advanced to from `head`, following each row's shift_to_code link as it was
  # BEFORE this save as well as as it is now (for a later performance, called
  # before the new row lands, the two are the same). The head itself is left
  # alone, as are auto-attach classes (force-available on every save and read
  # as available everywhere, so switching one off here would hide it from sale
  # until this performance next happened to save) and rows whose Available box
  # staff changed in this very save (the form settles those). Stops at a
  # non-shiftable tier, a blank or unknown target, or a code already seen (a
  # mis-configured cycle).
  #
  # `available` records only whether a tier is on sale, not why, so this cannot
  # tell a shift-derived tier from one staff enabled by hand: both are reset.
  # Converging ladders (two heads shifting into one tier) share that target, so
  # resetting one head turns it off for the other too; propagate each head to
  # reconfigure them. A provenance column could later replace this walk.
  def reset_shift_ladder_from!(head)
    head_code = head.ticket_class&.class_code
    return if head_code.nil?

    visited = Set[head_code]
    pending = shift_links_of(head)
    reset_codes = []
    until pending.empty?
      code = pending.shift
      next if visited.include?(code)

      visited << code
      node = allocation(code)
      next if node.nil?

      pending.concat(shift_links_of(node))
      next if node.ticket_class.auto_attach? || node.saved_change_to_available? || !node.available?

      node.update!(available: false)
      reset_codes << node.ticket_class.class_code
    end
    return if reset_codes.empty?

    Rails.logger.info("Reset dynamic pricing ladder on #{performance_code} from #{head_code}: " \
                      "switched off #{reset_codes.join(', ')}")
  end

  # The tier codes a row shifts to, before this save and now (usually one).
  def shift_links_of(node)
    former_shiftable = node.saved_changes.key?('shiftable') ? node.saved_changes['shiftable'].first : node.shiftable?
    former_code = node.saved_changes.key?('shift_to_code') ? node.saved_changes['shift_to_code'].first : node.shift_to_code
    links = []
    links << former_code if former_shiftable && former_code.present?
    links << node.shift_to_code if node.shiftable? && node.shift_to_code.present?
    links.uniq
  end

  # Every other performance of this production on/after this one's date and
  # time (performance_date and performance_time are separate columns, so the
  # same-day case compares the TIME column). Status is deliberately not
  # filtered: enabling an allocation on a not-yet-active performance is
  # harmless and matches the "whole rest of the run" intent.
  def later_performances_in_run
    Performance.unscoped
               .where(production_id: production_id)
               .where.not(id: id)
               .where('performance_date > :d OR (performance_date = :d AND performance_time >= :t)',
                      d: performance_date, t: performance_time)
  end

  def allocation(class_code)
    ticket_class_allocations.select do |tca|
      !tca.ticket_class.nil? && tca.ticket_class.class_code.eql?(class_code)
    end.first
  end

  def to_s
    "#{production.name} [#{datetime_s}] (#{number_of_seats_left} Seats Left)"
  end

  def to_short_s
    "#{production.name} on #{datetime_s}"
  end

  def datetime_s
    "#{performance_date.strftime('%m/%d')} #{performance_time.strftime('%H:%M')}"
  end

  def inactive?
    status == Performance::INACTIVE
  end

  # The special features patrons see, on the website and in emails. A feature
  # set to Inactive stays checked on the performance but is hidden. Filters in
  # memory so callers that preload :special_features (the calendar and list)
  # don't issue a query per performance.
  def active_special_features
    special_features.select(&:active?)
  end

  # Identity of this performance's "Custom Special Feature" copy within a
  # calendar's footnote list, or nil when there is none. The key is the copy
  # itself rather than the performance id, so performances repeating the same
  # note collapse into a single footnote instead of one footnote apiece.
  def custom_footnote_key
    return nil if special_feature_display_markdown.blank?

    "#{CUSTOM_FOOTNOTE_PREFIX}#{special_feature_display_markdown.strip}"
  end

  def self.custom_footnote?(key)
    key.to_s.start_with?(CUSTOM_FOOTNOTE_PREFIX)
  end

  def self.custom_footnote_text(key)
    key.to_s.delete_prefix(CUSTOM_FOOTNOTE_PREFIX)
  end

  def self.sellable_statuses
    [Performance::ACTIVE, Performance::PRIVATE]
  end

  def self.visible_statuses
    [Performance::ACTIVE]
  end

  def visible?
    Performance.visible_statuses.include?(status)
  end

  def manage_seat_inventory
    return if seat_map.nil? 

      seats = Seat.where(seat_map_id: seat_map.id)
      known_seats = seat_assignments.map { |sa| sa.seat }
      missing_seats = seats.map { |s| s } - known_seats

      missing_seats.each do |seat|
        seat_assignments << SeatAssignment.new(seat: seat)
      end
    
  end

  def remove_illegal_seat_assignments
    return if seat_map.nil? 

      seats = Seat.where(seat_map_id: seat_map.id)
      known_seats = seat_assignments.map { |sa| sa.seat }
      problem_seats = known_seats - seats.map { |s| s }
      problem_seats.each do |s|
        seat_assignments.select { |sa| sa.seat_id == s.id }.each do |sa|
          if sa.order_id.nil? && sa.status == "Available"
            sa.destroy
          else
            Rails.logger.error "Seat Assignment #{sa.id} is for seat map #{sa.seat.seat_map_id}, location #{sa.seat.location} and is #{sa.status} to order #{sa.order_id}"
          end
        end
      end
    
  end

  # generates a png based on the current seating chart for a seating preview for this performance
  #
  # if the thumbnail exists and no further reservations have been made, returns the cached image
  # all images are stored in public/qv as PERFORMANCECODE_seating.png
  #
  # @return image_path to generated image, empty string if the production is not reserved seating
  def generate_seating_thumbnail
    if production.has_reserved_seating? then
      file_name = performance_code + '_seating.png'
      file_path = Rails.root.join('public', 'static', 'qv', file_name).to_s
      if !File.exist?(file_path) || (File.mtime(file_path) < (seat_assignments.maximum(:updated_at) || Time.now) + 5.minutes)
        dots = SeatAssignment.joins(:seat).includes(:seat).where(performance_id: id, status: SeatAssignment::AVAILABLE).pluck(
          :origin_x, :origin_y, :width
        )
        result = MiniMagick::Image.open(seat_map.base_image_map_file)
        'available_seat.png'
        MiniMagick::Image.open(Rails.root.to_s + "/app/assets/images/available_seat.png")
        availables = {}

        dots.each do |dot|
          if availables[dot[2]].nil?
            availables[dot[2]] =
              MiniMagick::Image.open(Rails.root.to_s + "/app/assets/images/available_seat.png").resize("#{dot[2] * 2}x#{dot[2] * 2}")
          end
          result = result.composite(availables[dot[2]]) do |c|
            c.compose('over')
            c.geometry("+#{dot[0] - dot[2]}+#{dot[1] - dot[2]}")
          end
        end
        result.resize("225x225").write(file_path)
      end
      image_path = '/static/qv/' + file_name
    else
      image_path = ''
    end
    image_path
  end

  private

  def performance_code_must_match_production
    unless performance_code.starts_with?(production.production_code)
      errors.add(:performance_code,
                 "must start with #{production.production_code}")
    end
  end

  def clean_values
    scrub_string_attributes
    self.performance_date = Date.current if performance_date.nil?
    self.performance_time = Time.current if performance_time.nil?
    self.performance_date = performance_date.change(:hour => 0,
                                                    :min => 0,
                                                    :sec => 0,
                                                    :usec => 0)
    self.performance_time = performance_time.change(:year => performance_date.year,
                                                    :month => performance_date.month,
                                                    :day => performance_date.day,
                                                    :min => ((performance_time.min.to_i / 15) * 15),
                                                    :sec => 0,
                                                    :usec => 0)
    performance_code.upcase! if performance_code
  end

  def protect_performances_with_orders
    errors.add(:performance_code, " has associated ticket orders and cannot be deleted") unless orders.empty?
    orders.size.eql?(0)
  end

  def create_metrics
    create_house_count(total_seats: production.capacity, available_seats: production.capacity)
  end
end
