require 'rails_helper'

# Characterization spec for the nested-params iteration in
# Admin::TicketOrdersController#set_ticket_classes_for_line_items. A rubocop
# autocorrect rewrote `.values.each` into `.each_value` on the
# ticket_line_items_attributes ActionController::Parameters. These are equivalent
# (each_value yields the converted nested Parameters); this pins that EVERY nested
# line-item entry is visited and reassigned by ticket_class_code.
RSpec.describe Admin::TicketOrdersController, type: :controller do
  describe '#ensure_splittable' do
    it 'redirects to show with an error when the order is not splittable' do
      order = double('order', splittable?: false, id: 42)
      controller.instance_variable_set(:@ticket_order, order)
      allow(controller).to receive(:redirect_to)

      controller.send(:ensure_splittable)

      expect(controller).to have_received(:redirect_to).with(action: 'show', id: 42)
      expect(controller.flash[:error]).to eq('This order cannot be split.')
    end

    it 'does nothing when the order is splittable' do
      order = double('order', splittable?: true, id: 42)
      controller.instance_variable_set(:@ticket_order, order)
      allow(controller).to receive(:redirect_to)

      controller.send(:ensure_splittable)

      expect(controller).not_to have_received(:redirect_to)
    end
  end

  describe '#set_ticket_classes_for_line_items' do
    it 'reassigns the ticket class for every nested line-item entry by code' do
      adult  = double('adult class', class_code: 'ADULT')
      senior = double('senior class', class_code: 'SENIOR')
      allocations = [
        double('adult allocation', ticket_class: adult, available?: true),
        double('senior allocation', ticket_class: senior, available?: true)
      ]
      performance = double('performance', ticket_class_allocations: allocations)

      tli1 = double('line item 1', id: 1)
      tli2 = double('line item 2', id: 2)
      allow(tli1).to receive(:ticket_class=)
      allow(tli2).to receive(:ticket_class=)
      # keep them out of the trailing "drop unmatched" sweep
      allow(tli1).to receive(:ticket_class).and_return(adult)
      allow(tli2).to receive(:ticket_class).and_return(senior)
      order = double('order', ticket_line_items: [tli1, tli2], performance: performance)

      params = ActionController::Parameters.new(
        ticket_order: {
          ticket_line_items_attributes: {
            '0' => { id: '1', ticket_class_code: 'ADULT' },
            '1' => { id: '2', ticket_class_code: 'SENIOR' }
          }
        }
      )
      allow(controller).to receive(:params).and_return(params)

      controller.send(:set_ticket_classes_for_line_items, order)

      expect(tli1).to have_received(:ticket_class=).with(adult)
      expect(tli2).to have_received(:ticket_class=).with(senior)
    end

    it 'is a no-op when there are no ticket_line_items_attributes' do
      order = double('order')
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(ticket_order: {})
      )

      expect { controller.send(:set_ticket_classes_for_line_items, order) }.not_to raise_error
    end
  end
end
