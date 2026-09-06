require 'rails_helper'

RSpec.describe SiteTheme do
  # The suite runs with no theme installed, against the generic copy, so that a
  # broken default cannot hide behind a theme override. These examples drive
  # resolution with plain hashes, and install the real `theaterwit` theme only
  # inside a block that puts everything back.

  describe '.slug' do
    it 'returns the configured slug' do
      expect(described_class.slug('site_theme' => 'theaterwit')).to eq('theaterwit')
    end

    it 'accepts a symbol-keyed config, as specs and rake tasks pass' do
      expect(described_class.slug(site_theme: 'theaterwit')).to eq('theaterwit')
    end

    it 'is nil when no theme is configured' do
      expect(described_class.slug({})).to be_nil
    end

    it 'is nil when the key is present but blank, as it ships in server.yml.example' do
      expect(described_class.slug('site_theme' => '  ')).to be_nil
    end

    # If this ever fails, someone has put site_theme in the test: block of their
    # config/server.yml and the rest of the suite is silently asserting against
    # that house's copy.
    it 'is nil in the test environment' do
      expect(described_class.slug).to be_nil
    end

    # A slug is a directory name under sites/ and nothing else. Raising blocks
    # both the typo and the traversal.
    ['../secrets', 'sites/theaterwit', 'Theater Wit', 'theater wit', 'theaterwit/', './x'].each do |bad|
      it "raises for #{bad.inspect}" do
        expect { described_class.slug('site_theme' => bad) }
          .to raise_error(described_class::InvalidSlug, /#{Regexp.escape(bad)}/)
      end
    end
  end

  describe '.root and .views_path' do
    it 'points at sites/<slug> inside the checkout' do
      expect(described_class.root('theaterwit')).to eq(Rails.root.join('sites/theaterwit'))
      expect(described_class.views_path('theaterwit')).to eq(Rails.root.join('sites/theaterwit/views'))
    end

    it 'is nil with no theme' do
      expect(described_class.root(nil)).to be_nil
      expect(described_class.views_path(nil)).to be_nil
    end

    it 'refuses a malformed slug rather than building a path out of it' do
      expect { described_class.root('../..') }.to raise_error(described_class::InvalidSlug)
    end
  end

  describe '.views_available?' do
    it 'is true for a theme that ships views' do
      expect(described_class.views_available?('theaterwit')).to be(true)
    end

    # The tolerated case: server.yml names a theme this checkout does not carry.
    # The initializer warns and serves generic copy rather than refusing to boot.
    it 'is false for a configured theme that is not in this checkout' do
      expect(described_class.views_available?('no-such-house')).to be(false)
    end

    it 'is false with no theme' do
      expect(described_class.views_available?(nil)).to be(false)
    end
  end

  describe '.locale_files' do
    it 'lists the theme locale files' do
      expect(described_class.locale_files('theaterwit'))
        .to include(Rails.root.join('sites/theaterwit/locales/en.yml').to_s)
    end

    it 'is empty for a theme with no locales, and with no theme' do
      expect(described_class.locale_files('no-such-house')).to eq([])
      expect(described_class.locale_files(nil)).to eq([])
    end
  end

  describe '.with_theme' do
    let(:theme_views) { Rails.root.join('sites/theaterwit/views').to_s }

    def view_path_strings(target)
      target.view_paths.map(&:to_s)
    end

    it 'prepends the theme views to controllers and mailers, ahead of app/views' do
      described_class.with_theme('theaterwit') do
        expect(view_path_strings(ActionMailer::Base).first).to eq(theme_views)
        expect(view_path_strings(ActionController::Base).first).to eq(theme_views)
      end
    end

    it 'restores the previous view paths afterwards' do
      before_mailer = view_path_strings(ActionMailer::Base)
      before_controller = view_path_strings(ActionController::Base)

      described_class.with_theme('theaterwit') { nil }

      expect(view_path_strings(ActionMailer::Base)).to eq(before_mailer)
      expect(view_path_strings(ActionController::Base)).to eq(before_controller)
    end

    it 'restores the view paths when the block raises' do
      before_mailer = view_path_strings(ActionMailer::Base)

      expect { described_class.with_theme('theaterwit') { raise 'boom' } }.to raise_error('boom')

      expect(view_path_strings(ActionMailer::Base)).to eq(before_mailer)
    end

    # The point of the whole mechanism: the same partial name resolves to the
    # theme's file while the theme is installed, and to the generic one after.
    it 'renders the theme override in place of the generic partial' do
      generic = ApplicationController.render(partial: 'shared/house_thanks_line')
      themed = described_class.with_theme('theaterwit') do
        ApplicationController.render(partial: 'shared/house_thanks_line')
      end

      expect(generic).not_to include('storefront theaters')
      expect(themed).to include('storefront theaters')
    end

    it 'appends the theme locales so their keys win, and takes them away again' do
      key = 'order_mailer.donation_thank_you.subject'
      generic = I18n.t(key)

      themed = described_class.with_theme('theaterwit') { I18n.t(key) }

      expect(generic).to eq('Thank you for your donation!')
      expect(themed).to eq('Thank you for your donation (you are AWESOME)!')
      expect(I18n.t(key)).to eq(generic)
    end
  end

  describe '.install!' do
    it 'refuses to install nothing' do
      expect { described_class.install!(nil) }.to raise_error(ArgumentError)
    end
  end

  # config/server.yml is gitignored and every developer's is real, so the two
  # interesting boot outcomes are exercised by re-running the initializer
  # against a stubbed config rather than by editing that file. Neither branch
  # here installs anything, so the process is left as the suite found it.
  describe 'config/initializers/site_theme.rb' do
    let(:initializer) { Rails.root.join('config/initializers/site_theme.rb').to_s }

    def boot_with(server_config)
      allow(Rails.configuration.x).to receive(:server_config).and_return(server_config)
      load initializer
    end

    it 'does nothing when no theme is configured' do
      expect(Rails.logger).not_to receive(:warn)

      expect { boot_with({}) }.not_to raise_error
    end

    # Theater Wit's production checkout carries no sites/ directory, and a
    # deployment that has not shipped one yet must still serve.
    it 'warns and serves generic copy when the configured theme is not in this checkout' do
      expect(Rails.logger).to receive(:warn).with(/no-such-house/)

      boot_with('site_theme' => 'no-such-house')
    end

    # The success path, which is otherwise only exercised by a real deployment.
    # It installs into the same process the rest of the suite renders in, so
    # everything it touches is snapshotted and put back.
    it 'prepends the theme views and appends its locales when the theme is present' do
      before_controller = ActionController::Base.view_paths
      before_mailer = ActionMailer::Base.view_paths
      before_locales = Rails.application.config.i18n.load_path.dup
      theme_views = Rails.root.join('sites/theaterwit/views').to_s

      begin
        boot_with('site_theme' => 'theaterwit')

        expect(ActionController::Base.view_paths.map(&:to_s).first).to eq(theme_views)
        expect(ActionMailer::Base.view_paths.map(&:to_s).first).to eq(theme_views)
        expect(Rails.application.config.i18n.load_path - before_locales)
          .to eq([Rails.root.join('sites/theaterwit/locales/en.yml').to_s])
      ensure
        ActionController::Base.view_paths = before_controller
        ActionMailer::Base.view_paths = before_mailer
        Rails.application.config.i18n.load_path = before_locales
      end
    end

    it 'refuses to boot on a malformed slug rather than quietly serving generic copy' do
      expect { boot_with('site_theme' => '../../etc') }.to raise_error(described_class::InvalidSlug)
    end
  end
end
