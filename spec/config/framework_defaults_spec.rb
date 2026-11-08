require 'rails_helper'

# Guards config.load_defaults 6.1 and the explicit holds in config/application.rb.
# authlogic 6.4.3 loaded ActiveRecord::Base during Bundler.require, so the
# Active Record and Active Job framework defaults were silently ignored. 6.5.0
# loads lazily; legacy_connection_handling being false is the observable proof.
RSpec.describe 'framework defaults' do
  it 'applies the Active Record 6.1 defaults now that authlogic loads lazily' do
    expect(ActiveRecord::Base.legacy_connection_handling).to be(false)
  end

  it 'applies the Active Job 6.1 retry jitter' do
    expect(ActiveJob::Base.retry_jitter).to eq(0.15)
  end

  it 'skips after callbacks when a before callback aborts' do
    expect(ActiveJob::Base.skip_after_callbacks_if_terminated).to be(true)
  end

  it 'tracks Active Storage variants' do
    expect(ActiveStorage.track_variants).to be(true)
  end

  it 'holds has_many_inversing off unless HAS_MANY_INVERSING=1' do
    expect(ActiveRecord::Base.has_many_inversing).to eq(ENV['HAS_MANY_INVERSING'] == '1')
  end

  it 'holds cookie SameSite protection at the pre-6.1 value' do
    expect(Rails.application.config.action_dispatch.cookies_same_site_protection).to be_nil
  end

  it 'holds CSRF tokens at the pre-6.1 encoding' do
    expect(ActionController::Base.urlsafe_csrf_tokens).to be(false)
  end
end
