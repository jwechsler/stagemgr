# Save a screenshot and the page HTML when a browser (@javascript) scenario
# fails, so a CI failure can be read from the uploaded artifact
# (.github/workflows/test.yml uploads tmp/capybara).
FAILURE_ARTIFACT_DIR = Rails.root.join('tmp/capybara')

After do |scenario|
  next unless scenario.failed? && Capybara.current_driver != :rack_test

  FileUtils.mkdir_p(FAILURE_ARTIFACT_DIR)
  base = FAILURE_ARTIFACT_DIR.join(scenario.name.parameterize.first(100)).to_s
  begin
    page.save_screenshot("#{base}.png") # rubocop:disable Lint/Debugger -- deliberate failure artifact, not a leftover
    File.write("#{base}.html", page.html)
  rescue StandardError => e
    warn "Could not save failure artifacts for #{scenario.name}: #{e.message}"
  end
end
