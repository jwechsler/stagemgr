class FileStore < ApplicationRecord
  belongs_to :user, inverse_of: :file_stores
  has_one_attached :datafile

  FILE_WORKERS = (
    IMPORT, REPORT =
      "import", "report"
  )

  FILE_FORMATS = (
    TRG_LIST_IMPORT_FORMAT, MAILING_CARD_IMPORT_FORMAT, SEATMAP_GEOMETRY, EXTERNAL_CONTACT_FORMAT, BULK_ORDER_FORMAT, DONATION_LEVELS_IMPORT_FORMAT =
      "TRGArts List Import", "Mailing Card Format", "Seatmap Geometry", "External Contact Format", "Bulk Order Format",
"Donation Levels Import Format")

  def is_trg_list_format?
    true
  end

  def is_mailing_card_format?
    true
  end

  def path
    ActiveStorage::Blob.service.path_for(self.datafile.key)
  end

  def file_name
    self.datafile.filename.to_s
  end

  def file_size
    self.datafile.byte_size
  end
end
