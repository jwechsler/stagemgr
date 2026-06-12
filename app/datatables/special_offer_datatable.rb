class SpecialOfferDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      code: { source: 'SpecialOffer.code' },
      number_of_uses: { source: 'SpecialOffer.number_of_uses' },
      status: { source: 'SpecialOffer.status' },
      expires: { source: 'SpecialOffer.auto_expire' },
      description: { searchable: false },
      actions: { searchable: false },
    }
  end

  def data
    records.map do |special_offer|
      {
        id: special_offer.decorate.id,
        code: special_offer.decorate.code,
        description: special_offer.decorate.description,
        number_of_uses: special_offer.number_of_uses,
        status: special_offer.status,
        expires: (special_offer.auto_expire.nil? ? "n/a" : special_offer.auto_expire.to_s),
        DT_RowID: special_offer.id,
      }
    end
  end

  def initialize(params, opts = {})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    # t_ids = Theater.where("status != 'Inactive'").map {|x| x.id}
    # prod_ids = Production.where("status != 'Inactive'").map {|x| x.id}
    # perf_ids = Performance.where("status != 'Inactive' and production_id in (?)",prod_ids).map {|x| x.id}
    # prevent scan... or (theater_id is null and performance_id is null and production_id is null)
    # .order("code, performance_id, production_id, theater_id")
    special_offers = SpecialOffer.where(system_generated: false).order(:code)
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
