require 'rails_helper'
require 'method_source'

# Regression guard for Rails callback-halting semantics. Since Rails 5 a
# before_* callback halts only with throw(:abort) (returning false does
# nothing), and a `validate :method` counts only what it adds to errors (its
# return value is ignored, and a throw there escapes as UncaughtThrowError).
# Reads the source of every symbol callback/validator defined under app/;
# one example per model.
module CallbackHaltingLint
  # "Model#method (rule)" => why the hit is legitimate.
  ALLOWLIST = {
    'TicketOrder#seat_assignments_complete? (R1)' =>
      'errors.add precedes each `return false`; the value also serves the admin status bar predicate',
    'Order#validate_membership_payments (R4)' =>
      'refuses by raising from Membership#verify_applicable_for, not via errors (by design)'
  }.freeze

  APP_ROOT = Rails.root.join('app').to_s
  HALTING_CHAINS = %w[_validation_callbacks _save_callbacks _create_callbacks
                      _update_callbacks _destroy_callbacks].freeze
  ERRORS_WRITE = /errors\.(add|merge!|import)\b|errors\[[^\]]+\]\s*<</
  BARE_FALSE = /^\s*(return\s+)?false\s*(#.*)?$/
  THROW = /\bthrow\b/
  # A last line that only yields a boolean: `return x`, `!x`, `x?`, `x == y`.
  BOOLEAN_RESULT = /\A(return\s+\S|!|.*\?(\(.*\))?\z|.*(==|!=|\.eql\?))/
  # `x = y if z?` / `x.save! unless y.nil?` end in a predicate but yield no flag.
  MODIFIER = /\s(if|unless)\s/

  module_function

  # Rails.application.eager_load! skips app/models here (the autoload_paths
  # glob adds "app/models/", which Zeitwerk then excludes from eager loading),
  # so load every model file explicitly.
  def load_models
    loader = Rails.autoloaders.main
    Dir[File.join(APP_ROOT, 'models/**/*.rb')].each { |file| loader.load_file(file) }
    ApplicationRecord.descendants.reject(&:abstract_class?).sort_by(&:name)
  end

  def offenses_for(model)
    raw_offenses(model) - ALLOWLIST.keys
  end

  def raw_offenses(model)
    halting = HALTING_CHAINS.flat_map { |chain| own_filters(model, chain, %i[before around]) }.uniq
    validators = own_filters(model, '_validate_callbacks', %i[before])
    (halting.flat_map { |name| labels(model, name, halting_rules(app_source(model, name))) } +
      validators.flat_map { |name| labels(model, name, validate_rules(app_source(model, name))) }).uniq
  end

  # Symbol filters this model runs whose method it defines itself (or gets
  # from a module). A method a parent model defines and also registers is
  # reported on that parent instead.
  def own_filters(model, chain, kinds)
    model.send(chain).select { |cb| cb.filter.is_a?(Symbol) && kinds.include?(cb.kind) }.map(&:filter).select do |name|
      owner = model.instance_method(name).owner
      owner == model || !owner.is_a?(Class) || owner.send(chain).none? { |cb| cb.filter == name }
    rescue NameError
      false
    end
  end

  def halting_rules(body)
    return [] if body.nil?

    throw_at = body.index(THROW)
    [('R1' if bare_false?(body) || (throw_at.nil? && boolean_result?(body))),
     ('R2' if throw_at && !body[0...throw_at].match?(ERRORS_WRITE))].compact
  end

  def validate_rules(body)
    return [] if body.nil?

    [('R1' if bare_false?(body)),
     ('R3' if body.match?(THROW)),
     ('R4' unless body.match?(ERRORS_WRITE))].compact
  end

  def bare_false?(body)
    body.lines.any? { |line| line.match?(BARE_FALSE) }
  end

  # A one-expression predicate body (`def x; y?; end`) or a last line that
  # only computes a boolean, which the callback chain then ignores.
  def boolean_result?(body)
    lines = body.lines.map(&:strip).reject(&:empty?)
    return false if lines.size < 3 || lines.last != 'end'

    lines[-2].match?(BOOLEAN_RESULT) && !lines[-2].match?(MODIFIER)
  end

  def labels(model, name, rules)
    rules.map { |rule| "#{model.name}##{name} (#{rule})" }
  end

  # Method source without comment lines, or nil when not defined under app/.
  def app_source(model, name)
    method = model.instance_method(name)
    return unless method.source_location&.first&.start_with?(APP_ROOT)

    method.source.lines.reject { |line| line.strip.start_with?('#') }.join
  rescue MethodSource::SourceNotFoundError
    nil
  end
end

RSpec.describe 'ActiveRecord callback halting lint' do
  models = CallbackHaltingLint.load_models

  models.each do |model|
    it "#{model.name} halts with throw(:abort) and validates through errors" do
      offenses = CallbackHaltingLint.offenses_for(model)
      expect(offenses).to be_empty, <<~MSG
        #{offenses.join("\n")}
        R1: returns false / a boolean (neither halts nor invalidates)
        R2: throw without errors.add before it
        R3: throw inside a validate method
        R4: validate method never writes to errors
        Fix the method, or add it to CallbackHaltingLint::ALLOWLIST with a reason.
      MSG
    end
  end

  it 'has no stale allowlist entries' do
    live = models.flat_map { |model| CallbackHaltingLint.raw_offenses(model) }
    expect(CallbackHaltingLint::ALLOWLIST.keys - live).to be_empty
  end
end
