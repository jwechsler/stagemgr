# Helpers for steps that check which Sprockets bundles a page includes and
# what a served bundle contains (features/public_reserved_seating.feature,
# features/public_order_scripts.feature,
# features/admin_refund_to_donation.feature).
module ScriptBundleHelpers
  # One line of jQuery's banner: present once per copy of jQuery.
  JQUERY_MARKER = 'jQuery JavaScript Library'.freeze

  # Sprockets serves every local bundle under /assets/ (the esbuild seat map
  # editor bundle included); scripts loaded from elsewhere are not bundles.
  SPROCKETS_PREFIX = '/assets/'.freeze

  # The logical names of the page's Sprockets <script src> bundles, digest
  # stripped: "/assets/application-0f3c.js" is "application".
  def page_script_bundles
    sprockets_scripts.map do |script|
      File.basename(URI(script[:src]).path, '.js').sub(/-\h{8,}\z/, '').sub(/\.(self|debug)\z/, '')
    end
  end

  def sprockets_scripts
    all('script[src]', visible: :all).select { |script| URI(script[:src]).path.start_with?(SPROCKETS_PREFIX) }
  end

  # The served source of the page's +bundle+ Sprockets script, fetched by the
  # browser.
  def served_bundle_source(bundle)
    script = sprockets_scripts.find { |s| File.basename(URI(s[:src]).path).start_with?("#{bundle}-", "#{bundle}.") }
    raise "The page has no #{bundle} script" if script.nil?

    page.evaluate_async_script(<<~JS, script[:src])
      var done = arguments[arguments.length - 1];
      fetch(arguments[0])
        .then(function(response) { return response.text(); })
        .then(done, function(error) { done('fetch failed: ' + error); });
    JS
  end
end

World(ScriptBundleHelpers)
