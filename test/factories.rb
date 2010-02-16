Factory.define(:user) do |user|
  user.sequence(:email) {|n| "stagemgr#{n}@example.com"}
  user.password 'password'
  user.password_confirmation 'password'
end
