# frozen_string_literal: true

require 'rails_helper'

# Runs the real child process (bin/render-membership-card) end to end.
RSpec.describe MembershipCards::RenderProcess, :membership_cards do
  let(:background_path) { image_file(synthetic_background) }

  def inputs(**overrides)
    MembershipCards::Renderer::Inputs.new(
      { background_path: background_path, front_path: nil, photo_path: nil,
        name_font: helvetica_bold, label_font: helvetica,
        name: 'Jo Ann', member_number: 'TW-ABC123', year: '2019' }.merge(overrides)
    )
  end

  it 'returns the PNG rendered by the child process' do
    png = described_class.run(inputs, logger: nil)
    image = Vips::Image.new_from_buffer(png, '')

    expect([image.width, image.height]).to eq([card_spec.width, card_spec.height])
    expect(image.xres).to be_within(0.01).of(card_spec.dpi / 25.4)
  end

  it 'registers an uploaded font file in the child before rendering' do
    path = system_bold_font_path || skip('fontconfig has no bold .ttf/.otf font to register')
    font = MembershipCards::FontFile.new(path).to_font
    logger = instance_double(Logger)
    allow(logger).to receive(:warn)

    png = described_class.run(inputs(name_font: font, label_font: font), logger: logger)

    expect(Vips::Image.new_from_buffer(png, '').width).to eq(card_spec.width)
    expect(logger).not_to have_received(:warn).with(/not available to Pango/)
  end

  it 'raises RenderError with the child diagnostics when the render fails' do
    stale = image_file(synthetic_background(width: 10, height: 10))

    expect { described_class.run(inputs(background_path: stale), logger: nil) }
      .to raise_error(MembershipCards::RenderError, /10x10/)
  end

  it 'raises RenderError when a font file is missing' do
    ghost = MembershipCards::Font.new('/nonexistent/font.otf', 'Ghost')

    expect { described_class.run(inputs(name_font: ghost), logger: nil) }
      .to raise_error(MembershipCards::RenderError, /font file missing/)
  end
end
