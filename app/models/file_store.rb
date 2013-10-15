class FileStore < ActiveRecord::Base
  belongs_to :user
  has_attached_file :data, {
    :path=>":rails_root/public/system/filestore/:hash/:filename",
    :url=>"/system/filestore/:hash/:filename",
    :hash_secret => $SERVER_CONFIG['filestore_hash']
  }

  FILE_WORKERS = (
    IMPORT, REPORT =
    "import", "report"
    )

  FILE_FORMATS = (
    TRG_LIST_IMPORT_FORMAT =
    "TRGArts List Import")

  def is_trg_list_format?
    true
  end

end
