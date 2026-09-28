# Boot-time patches to gem and framework classes. Both files are ignored by the
# main autoloader (config/application.rb): they reopen constants Zeitwerk does
# not own, so they are loaded once here and never reloaded. Everything else in
# lib/ is autoloaded on first reference, like app/ -- an initializer must not
# require those, because that makes it load a reloadable constant at boot (a
# deprecation on 6.1, a NameError on 7.0).
require Rails.root.join('lib/validates_credit_card').to_s
require Rails.root.join('lib/extensions/my_emma_patches').to_s

# MyEmma::Member belongs to the my_emma gem, so it survives a development
# reload and the include runs exactly once per process.
MyEmma::Member.include MyEmmaPatches::Member
