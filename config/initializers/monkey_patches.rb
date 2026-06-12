Dir[Rails.root.join('lib/extensions/*.rb')].each { |f| require f }
Dir[Rails.root.join('lib/*.rb')].each { |f| require f }

# Apply the monkey patches
MyEmma::Member.include MyEmmaPatches::Member
