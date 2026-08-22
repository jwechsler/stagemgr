require 'rails_helper'

# The ExceptionNotification middleware is configured only in production.rb, so no
# spec can exercise it. This textual check is the only thing standing between a
# future refactor and silently shipping a notifier with no User section again.
RSpec.describe 'production exception notifier configuration' do
  let(:config) { Rails.root.join('config/environments/production.rb').read }

  it 'declares the user section ahead of the stock sections' do
    expect(config).to match(/sections:\s*%w\[user request session environment backtrace\]/)
  end

  # EmailNotifier appends 'data' itself when exception_data or the :data option
  # is non-empty. Listing it explicitly would render the section twice.
  it 'does not list the auto-appended data section' do
    expect(config).not_to match(/sections:\s*%w\[[^\]]*\bdata\b/)
  end
end
