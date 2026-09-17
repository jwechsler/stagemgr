# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipCards::NameFitter do
  # Every character is 0.55 em wide: a name of n characters at size s measures
  # 0.55 * n * s px. Deterministic and font-free.
  let(:measurer) { ->(text, size) { text.length * 0.55 * size } }
  let(:rules)    { MembershipCards::Spec.default.name_rules }
  let(:fitter)   { described_class.new(rules, measurer) }

  # From the spec: box 567 x 132.3 at (66.1, 251), max 85 px, step 1.1811,
  # line height 0.98 em, first baseline 0.8452 em, 2 px fit margin.
  let(:max_width)  { rules.box.w - rules.fit_margin }
  let(:max_height) { rules.box.h - rules.fit_margin }

  it 'keeps a short name on one line at the maximum size' do
    fit = fitter.fit('Jo Ann')

    expect(fit.font_size).to eq(rules.max_font_size)
    expect(fit.lines).to eq(['Jo Ann'])
    expect(fit.baselines.first).to be_within(0.01).of(rules.box.y + (rules.first_baseline_ratio * 85))
  end

  it 'prefers shrinking onto one line when that happens before two lines fit' do
    # 15 characters fit one 565 px line at 68.5 px, before two lines fit the height.
    fit = fitter.fit('Alexandra Vance')

    expect(fit.lines).to eq(['Alexandra Vance'])
    expect(fit.font_size).to be < rules.max_font_size
    expect(measurer.call('Alexandra Vance', fit.font_size)).to be <= max_width
    expect(measurer.call('Alexandra Vance', fit.font_size + rules.shrink_step)).to be > max_width
  end

  # 21 characters: one line would need 49 px, so the fitter settles on two
  # lines at the largest size whose two line heights fit the box.
  let(:two_line_name) { 'Alexandra Vance Wells' }

  it 'wraps after a space when the name is too wide for one line' do
    fit = fitter.fit(two_line_name)

    expect(fit.lines).to eq(['Alexandra Vance', 'Wells'])
  end

  it 'breaks after a hyphen, keeping the hyphen on the first line' do
    # 21 characters with no space: only the hyphen offers a break.
    fit = fitter.fit('Marguerite-Wellington')

    expect(fit.lines).to eq(['Marguerite-', 'Wellington'])
  end

  it 'shrinks in fixed steps until two lines fit the box height' do
    fit = fitter.fit(two_line_name)

    # 0.98 * 2 * s <= 130.3  ->  s <= 66.48; from 85 in 1.1811 steps that is 16 steps.
    steps = ((85 - (max_height / (2 * rules.line_height_ratio))) / rules.shrink_step).ceil
    expect(fit.font_size).to be_within(0.001).of(85 - (steps * rules.shrink_step))
    expect(rules.line_height_ratio * fit.font_size * 2).to be <= max_height
    expect(rules.line_height_ratio * (fit.font_size + rules.shrink_step) * 2).to be > max_height
  end

  it 'spaces the second baseline one line height below the first' do
    fit = fitter.fit(two_line_name)

    expect(fit.baselines.size).to eq(2)
    expect(fit.baselines[1] - fit.baselines[0]).to be_within(0.001).of(rules.line_height_ratio * fit.font_size)
  end

  it 'measures a line without its trailing space' do
    seen = []
    spy = lambda do |text, size|
      seen << text
      measurer.call(text, size)
    end

    described_class.new(rules, spy).fit(two_line_name)

    expect(seen).not_to include(match(/ \z/))
  end

  it 'honours the fit margin rather than the raw box width' do
    # 12 characters at 85 px = 561 px: inside the 567 box, outside 565.
    tight = ->(text, size) { text == 'Marguerite-A' ? 566 : measurer.call(text, size) }

    fit = described_class.new(rules, tight).fit('Marguerite-A B')

    expect(fit.lines.first).not_to eq('Marguerite-A')
  end

  it 'raises when even the smallest size cannot fit an unbreakable name' do
    expect { fitter.fit('X' * 200) }.to raise_error(MembershipCards::NameFitter::TooLong)
  end
end
