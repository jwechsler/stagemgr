Factory.define(:user) do |user|
  user.sequence(:email) {|n| "stagemgr#{n}@example.com"}
  user.password 'password'
  user.password_confirmation 'password'
end

Factory.define(:theater) do |theater|
  theater.sequence(:name){|n|"Theater \##{n}"}
  theater.theater_class Theater::THEATER_CLASSES.first
  theater.status Theater::THEATER_STATUSES.first
end

Factory.define(:production) do |production|
  production.sequence(:name){|n|"Production \##{n}"}
  production.status Production::PRODUCTION_STATUSES.first
  production.association :theater, :factory => :theater
end

Factory.define(:performance) do |performance|
  performance.association :production, :factory => :production
end

Factory.define(:ticket_class) do |ticket_class|
end
