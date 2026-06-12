class Metric < ApplicationRecord
  self.abstract_class = true
  # Including the MetricsExporter module to use its methods
  include MetricsExporter

  # Define this method in subclasses to specify the columns to be exported
  def self.export_columns
    raise NotImplementedError, "Subclasses must define `export_columns`."
  end

  # Define this method in subclasses to specify the records to be exported
  def self.export_records
    raise NotImplementedError, "Subclasses must define `export_records`."
  end
end
