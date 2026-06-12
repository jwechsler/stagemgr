# ./spec/jobs/export_house_counts_job_spec.rb

require 'rails_helper'

RSpec.describe ExportHouseCountsJob, type: :job do
  let(:temp_dir) { Rails.root.join('tmp/tests') }
  let(:file_path) { File.join(temp_dir, 'house_count.txt') }

  before do
    FileUtils.mkdir_p(temp_dir) # Ensure the directory exists
    production = FactoryBot.create(:production)
    performance1 = FactoryBot.create(:performance, production: production)
    performance2 = FactoryBot.create(:performance, performance_date: performance1.performance_date + 1.day,
                                                   production: production)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, performance: performance1)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, performance: performance1)
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2)
    CalculateHouseCountsJob.perform
  end

  after do
    FileUtils.rm_rf(temp_dir) # Clean up the directory after tests
  end

  it 'creates a file with the correct contents' do
    ExportHouseCountsJob.perform(file_path)

    content = File.read(file_path)

    # HUD-format table headers
    expect(content).to include('HOUSE COUNTS')
    expect(content).to include('| Code')
    expect(content).to include('| Sold')
    expect(content).to include('| Held')
    expect(content).to include('| Remaining')
    expect(content).to include('| Max Price')

    # MySQL-style borders
    expect(content).to include('+')
    expect(content).to include('---')

    # Data values
    expect(content).to include('96')
    expect(content).to include('98')

    # Footer
    expect(content).to include('Generated')
  end
end
