# ./spec/jobs/export_house_counts_job_spec.rb

require 'rails_helper'

RSpec.describe ExportHouseCountsJob, type: :job do
  let(:temp_dir) { Rails.root.join('tmp', 'tests') }
  let(:file_path) { File.join(temp_dir, 'house_count.txt') }

  before do
    FileUtils.mkdir_p(temp_dir)  # Ensure the directory exists
    production = FactoryBot.create(:production)
    performance1 = FactoryBot.create(:performance, production: production)
    performance2 = FactoryBot.create(:performance, performance_date: performance1.performance_date + 1.day, production: production)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, performance: performance1)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, performance: performance1)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2)
    CalculateHouseCountsJob.new.perform
  end

  after do
    FileUtils.rm_rf(temp_dir)  # Clean up the directory after tests
  end

  it 'creates a file with the correct contents' do
    # Assuming the job writes specific content to the file
    # Trigger the job
    ExportHouseCountsJob.new.perform(file_path)

    # Read the file
    content = File.read(file_path)

    # Assert the expected contents
    expect(content).to include("Performance Code")
    expect(content).to include("Total Seats")
    expect(content).to include("Available Seats")
    expect(content).to include("100")
    expect(content).to include("98")
    expect(content).to include("96")
  end
end
