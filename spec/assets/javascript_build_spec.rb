require 'rails_helper'

# JavascriptBuild (spec/support/javascript_build.rb) decides whether a test run
# must run `yarn build` first. Point it at a scratch output and input inside a
# tmp dir and set their mtimes explicitly, so no example depends on the real
# bundle or on the clock.
RSpec.describe JavascriptBuild do
  let(:dir) { Pathname.new(Dir.mktmpdir('javascript_build')) }
  let(:output) { dir.join('builds/seat_map_editor.js') }
  let(:input) { dir.join('javascript/seat_map_editor.js') }
  let(:earlier) { Time.zone.local(2026, 1, 1, 12, 0, 0).to_time }
  let(:later) { earlier + 1.hour }

  before do
    input.dirname.mkpath
    File.write(input, '// source')
    File.utime(earlier, earlier, input)
    # Rails.root.join with an absolute path returns that path, so the
    # absolute glob below keeps the scan inside the tmp dir.
    stub_const('JavascriptBuild::OUTPUT', output)
    stub_const('JavascriptBuild::INPUT_GLOBS', [dir.join('javascript/**/*.js').to_s])
  end

  after { FileUtils.remove_entry(dir) }

  def write_output(mtime)
    output.dirname.mkpath
    File.write(output, '// bundle')
    File.utime(mtime, mtime, output)
  end

  describe '.stale?' do
    it 'returns true when the bundle has never been built' do
      expect(described_class.stale?).to be(true)
    end

    it 'returns true when an input is newer than the bundle' do
      write_output(earlier)
      File.utime(later, later, input)

      expect(described_class.stale?).to be(true)
    end

    it 'returns false when the bundle is newer than every input' do
      write_output(later)

      expect(described_class.stale?).to be(false)
    end
  end

  describe '.ensure_built!' do
    it 'does not run the build when the bundle is up to date' do
      write_output(later)
      allow(described_class).to receive(:system)

      described_class.ensure_built!

      expect(described_class).not_to have_received(:system)
    end

    it 'raises with a hint when the build command fails' do
      allow(described_class).to receive(:system).and_return(false)
      allow(described_class).to receive(:warn)

      expect { described_class.ensure_built! }.to raise_error(/`yarn build` failed/)
    end
  end
end
