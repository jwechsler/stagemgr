# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_stagemgr_session',
  :secret      => '5487daa93ac821a4814cd572a78a3d64ed34f2df749bf173f5d290bade1b196166b9fb5b0c5e52b54064cc5f3f337c2edfc0a87b9cdad7fd66191ed2aeeb74f4'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
