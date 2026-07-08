Given(/^a festival "([^"]*)" exists$/) do |name|
  @festival = FactoryBot.create(:festival, name: name)
end

Given(/^the production "([^"]*)" belongs to the festival "([^"]*)"$/) do |production_code, festival_name|
  production = Production.find_by_production_code(production_code) || Production.find_by_name(production_code)
  festival = Festival.find_by(name: festival_name)
  production.update!(festival: festival)
end

Then(/^the production "([^"]*)" should belong to the festival "([^"]*)"$/) do |production_code, festival_name|
  production = Production.find_by_production_code(production_code) || Production.find_by_name(production_code)
  expect(production.reload.festival&.name).to eq(festival_name)
end

Then(/^a festival "([^"]*)" should still exist$/) do |name|
  expect(Festival.exists?(name: name)).to be true
end
