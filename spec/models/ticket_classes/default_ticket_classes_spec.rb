describe DefaultTicketClass, :wip=>true do
  it "should create an identical copy of itself as an associated ticket class when a production is created" do
    default_ticket_class = FactoryBot.create(:default_ticket_class, :class_code=>'TEST')
    default_ticket_class.save
    production = FactoryBot.create(:production)
    ticket_class = production.ticket_classes.select{|tc| tc.class_code == default_ticket_class.class_code}.first
    default_attributes = default_ticket_class.to_hash
    default_attributes.keys.each {|key|
      expect(ticket_class.attributes).to include(key)
      expect(ticket_class[key]).to eq(default_attributes[key])
    }
  end

end
