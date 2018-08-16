class SpecialOfferDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :edit_admin_special_offer_path
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      code: { source: 'SpecialOffer.code' },
      number_of_uses: { source: 'SpecialOffer.number_of_uses' },
      status: { source: 'SpecialOffer.status' },
      expires: {source: 'SpecialOffer.auto_expire'}
    }
  end

  def additional_data
    {
      description: '',
      actions: ''
    }
  end

  def data
    records.map do |special_offer|
      {
        id: special_offer.id,
        code: link_to(special_offer.code, edit_admin_special_offer_path(special_offer)),
        description: special_offer.to_s,
        number_of_uses: special_offer.number_of_uses,
        status: special_offer.status,
        expires: (special_offer.auto_expire.nil? ? "n/a" : special_offer.auto_expire.to_s),
        DT_RowID: special_offer.id,
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    t_ids = Theater.where("status != 'Inactive'").map {|x| x.id}
    prod_ids = Production.where("status != 'Inactive'").map {|x| x.id}
    perf_ids = Performance.where("status != 'Inactive' and production_id in (?)",prod_ids).map {|x| x.id}
    # prevent scan... or (theater_id is null and performance_id is null and production_id is null)
    # .order("code, performance_id, production_id, theater_id")
    special_offers = SpecialOffer.where("system_generated = 0 and (theater_id in (?) or performance_id in (?)  or production_id in (?))",t_ids,perf_ids,prod_ids)
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
