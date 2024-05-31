# app/jobs/export_house_counts_job.rb
class ExportHouseCountsJob < ApplicationJob
  @queue = :report

  def file_path
    File.join($SERVER_CONFIG['hud_export_directory'],'house_count.txt')
  end

  def perform(file_path = nil)
    # Call the export method from the HouseCount model
    HouseCount.export_to_file(HouseCount.export_records, HouseCount.export_columns, file_path || self.file_path)
  end
end

