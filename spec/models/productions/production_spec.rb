require_relative "../../spec_helper.rb"

describe "a production" do
  context "with one order" do
    before(:each) do
      @ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    end

    it "should have one attendee when fulfilled" do
      expect(@ticket_order.performance.production.attendees.count).to eq(0)
      @ticket_order.transition_to!(Order::FULFILLED)
      expect(@ticket_order.performance.production.attendees.count).to eq(1)
    end
    it "can override the email links for surveys and mailing list solicitation" do
      mail = OrderMailer.standard_followup(@ticket_order)
      expect(mail.body.encoded).to match("SURVEYLINK.TEST")
      expect(mail.body.encoded).to match("MAILINGLINK.TEST")
      @ticket_order.performance.production.survey_link = "http://newsurvey.test"
      @ticket_order.performance.production.mailing_list_link = "http://newmailing.test"
      @ticket_order.performance.production.save!
      mail = OrderMailer.standard_followup(@ticket_order)
      expect(mail.body.encoded).to match("newsurvey.test")
      expect(mail.body.encoded).to match("newmailing.test")
    end
  end

  it "always stores custom label as lowercase" do
    @production = FactoryBot.create(:production)
    @production.custom_label = "BiGLabel"
    @production.save
    expect(@production.custom_label).to eq("biglabel")
  end

end
