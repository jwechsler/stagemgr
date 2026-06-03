require 'rails_helper'

RSpec.describe Report, type: :model do
  describe '#report_filename' do
    subject(:report) { Report.new([], nil) }

    def filename_for(name)
      report.send(:report_filename, name)
    end

    it 'writes a bare filename to the system tmpdir' do
      path = filename_for('broadcast-log-1.csv')
      expect(File.dirname(path)).to eq(Dir.tmpdir)
      expect(File.basename(path)).to eq('broadcast-log-1.csv')
    end

    it 'parameterizes spaces and punctuation in the filename' do
      path = filename_for('Weekly Box Office (Final).csv')
      expect(File.basename(path)).to eq('weekly-box-office-final.csv')
    end

    # Regression: a production name containing "/" used to make File.dirname
    # report a phantom directory ("Los Regalos"), bypassing the tmpdir fallback
    # and raising Errno::ENOENT when File.new tried to open it for writing.
    it 'does not treat a slash in the name as a directory' do
      path = filename_for('Los Regalos/The Gifts (Peru)-attendees-1.csv')
      expect(File.dirname(path)).to eq(Dir.tmpdir)
      expect(File.basename(path)).to eq('los-regalos-the-gifts-peru-attendees-1.csv')
      expect(Dir.exist?(File.dirname(path))).to be(true)
    end

    it 'produces a writable path for a slashed name' do
      path = filename_for('A/B/C-report.csv')
      expect { File.write(path, 'ok') }.not_to raise_error
      File.delete(path) if File.exist?(path)
    end

    it 'falls back to tmpdir when the supplied directory does not exist' do
      path = filename_for('/nonexistent/path/report.csv')
      expect(File.dirname(path)).to eq(Dir.tmpdir)
      expect(File.basename(path)).to eq('nonexistent-path-report.csv')
      expect { File.write(path, 'ok') }.not_to raise_error
      File.delete(path) if File.exist?(path)
    end

    it 'honors an explicitly supplied directory that exists' do
      path = filename_for(File.join(Dir.tmpdir, 'audience-cohort.csv'))
      expect(File.dirname(path)).to eq(Dir.tmpdir)
      expect(File.basename(path)).to eq('audience-cohort.csv')
    end

    it 'defaults the extension to .csv when none is given' do
      path = filename_for('some-report')
      expect(File.extname(path)).to eq('.csv')
    end
  end
end
