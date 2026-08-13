require 'rails_helper'

RSpec.describe TicketOrder, type: :model do
  describe '#build_tktprint_payload Latin-1 sanitization' do
    let(:order) { FactoryBot.create(:ticket_order, :for_a_single_ticket) }
    let(:non_latin1_re) { /[^\x00-ÿ]/ }

    before do
      order.performance.production.update!(
        name: 'Zoë’s “Big” Show — Act 1… 🎭',
        credit_lines: "Music by Dvořák\nChoreography — Łódź Ballet"
      )
      # Emoji included deliberately: unsanitized, it makes Namae fail to
      # parse and the name prints blank (regression from dev E2E testing).
      order.update!(hold_under: 'Zoë Dvořák 🎟️')
    end

    it 'restricts every string in the payload to the Latin-1 repertoire' do
      payload = order.reload.send(:build_tktprint_payload, 'BATCH-1', 1)

      expect(payload[:title]).to eq('Zoë\'s "Big" Show - Act 1...')
      expect(payload[:credit_1]).to eq('Music by Dvorák') # ř -> r, á kept
      expect(payload[:credit_2]).to eq('Choreography - Lódz Ballet')
      expect(payload[:first_name]).to eq('Zoë')
      expect(payload[:last_name]).to eq('Dvorák')

      # Whole wire body: nothing outside the Latin-1 repertoire survives.
      expect(payload.to_json).not_to match(non_latin1_re)
    end
  end
end
