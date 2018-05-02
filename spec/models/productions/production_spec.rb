require_relative "../../spec_helper.rb"

describe "a production" do
  context "with one order" do
    before(:each) do
      @ticket_order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    end

    after(:each) do
      Authorization.ignore_access_control(false)
    end

    it "should have one attendee when fulfilled" do
      @ticket_order.performance.production.attendees.count.should == 0
      @ticket_order.transition_to!(Order::FULFILLED)
      @ticket_order.performance.production.attendees.count.should == 1
    end
    it "can override the email links for surveys and mailing list solicitation" do
      Authorization.ignore_access_control(true)
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
    @production.custom_label.should.eql? "biglabel"
  end

end
