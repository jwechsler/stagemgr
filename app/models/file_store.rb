class FileStore < ActiveRecord::Base
  include SafeAttributes::Base
  belongs_to :user
  has_attached_file :data, {
    :path=>":rails_root/public/system/filestore/:hash/:filename",
    :url=>"#{Rails.application.config.action_controller.relative_url_root}/system/filestore/:hash/:filename",
    :hash_secret => $SERVER_CONFIG['filestore_hash']
  }
  validates_attachment_content_type :data, content_type: "text/plain"

  FILE_WORKERS = (
    IMPORT, REPORT =
    "import", "report"
    )

  FILE_FORMATS = (
    TRG_LIST_IMPORT_FORMAT, MAILING_CARD_IMPORT_FORMAT, SEATMAP_GEOMETRY, EXTERNAL_CONTACT_FORMAT, BULK_ORDER_FORMAT  =
    "TRGArts List Import", "Mailing Card Format", "Seatmap Geometry", "External Contact Format", "Bulk Order Format")

  def is_trg_list_format?
    true
  end

  def is_mailing_card_format?
    true
  end

end
