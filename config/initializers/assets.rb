# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')
# Foundation 6.9 SCSS source (replaces foundation-rails gem)
Rails.application.config.assets.paths << Rails.root.join('node_modules', 'foundation-sites', 'scss')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )

Rails.application.config.assets.precompile += %w[application.js]
Rails.application.config.assets.precompile += %w[backend.css admin_application.js frontend.css]
Rails.application.config.assets.precompile += %w[orders_common.js admin/orders_common.js seat_assignment.js
                                                 seat_map.js order_entry.js reseating.js]
