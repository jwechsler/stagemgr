Then("I visit the ticket classes page for production {string}") do |prod_name|
  prod = Production.find_by(name: prod_name)
  visit admin_theater_production_ticket_classes_path(prod.theater, prod)
end
