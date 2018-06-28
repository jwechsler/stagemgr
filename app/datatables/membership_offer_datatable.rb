class MembershipOfferDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'MembershipOffer.name' },
      cost: { source: 'MembershipOffer.recurring_cost' },
      on_sale: { source: 'MembershipOffer.on_sale' },
      status: { source: 'MembershipOffer.status' }
    }
  end

  def additional_data
    {
      actions: 'Hello'
    }
  end

  def data
    records.map do |record|
      {
        id: record.id,
        name: link_to(record.name, [:admin, record]),
        cost: number_to_currency(record.recurring_cost),
        on_sale: record.on_sale? ? '√' : '',
        status: record.active? ? link_to("Create Order", [:new, :admin, record, :order] ) : '(Inactive)',
        DT_RowID: record.id,
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    MembershipOffer.all
    # insert query here
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def sort_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
