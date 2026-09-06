require 'rails_helper'
require 'tmpdir'
require Rails.root.join('lib/tasks/setup/env_file')

RSpec.describe Setup::EnvFile do
  around do |example|
    Dir.mktmpdir('env-file-spec') do |dir|
      @path = File.join(dir, '.env')
      example.run
    end
  end

  attr_reader :path

  subject(:env) { described_class.new(path) }

  def write(contents)
    File.write(path, contents)
  end

  describe '#[]' do
    it 'reads a plain assignment' do
      write("SECRET_KEY_BASE=abc123\n")

      expect(env['SECRET_KEY_BASE']).to eq('abc123')
    end

    it 'strips matching surrounding quotes, as dotenv does' do
      write(%(SINGLE='abc'\nDOUBLE="def"\n))

      expect(env['SINGLE']).to eq('abc')
      expect(env['DOUBLE']).to eq('def')
    end

    it 'leaves an unmatched quote alone' do
      write(%(ODD="abc\n))

      expect(env['ODD']).to eq('"abc')
    end

    it 'tolerates a leading export' do
      write("export TOKEN=xyz\n")

      expect(env['TOKEN']).to eq('xyz')
    end

    # dotenv and docker compose both take the last assignment; a helper that
    # reported the first would show a value the app never sees.
    it 'returns the last assignment when a key is repeated' do
      write("TOKEN=first\nTOKEN=second\n")

      expect(env['TOKEN']).to eq('second')
    end

    it 'treats blank, commented and absent the same way' do
      write("BLANK=\nSPACES=   \n# COMMENTED=value\n")

      expect(env['BLANK']).to be_nil
      expect(env['SPACES']).to be_nil
      expect(env['COMMENTED']).to be_nil
      expect(env['NEVER_MENTIONED']).to be_nil
    end

    it 'returns nil when the file does not exist' do
      expect(env['ANYTHING']).to be_nil
    end
  end

  describe '#[]=' do
    it 'replaces the last assignment, not the first' do
      write("TOKEN=first\nOTHER=keep\nTOKEN=second\n")

      env['TOKEN'] = 'third'

      expect(File.read(path)).to eq("TOKEN=first\nOTHER=keep\nTOKEN=third\n")
      expect(env['TOKEN']).to eq('third')
    end

    it 'appends when the key is absent, preserving surrounding comments' do
      write("# a comment\nOTHER=keep\n")

      env['TOKEN'] = 'new'

      expect(File.read(path)).to eq("# a comment\nOTHER=keep\nTOKEN=new\n")
    end

    it 'creates the file when it does not exist' do
      env['TOKEN'] = 'new'

      expect(File.read(path)).to eq("TOKEN=new\n")
    end

    it 'terminates a final line that has no newline before appending' do
      write('OTHER=keep')

      env['TOKEN'] = 'new'

      expect(File.read(path)).to eq("OTHER=keep\nTOKEN=new\n")
    end

    it 'ignores a commented-out assignment and appends a live one' do
      write("# TOKEN=old\n")

      env['TOKEN'] = 'new'

      expect(File.read(path)).to eq("# TOKEN=old\nTOKEN=new\n")
    end

    # A newline in a value would inject an arbitrary extra assignment; a `$` or
    # a backtick would be interpolated by any shell that sources the file.
    it 'refuses a value containing a newline' do
      expect { env['TOKEN'] = "safe\nINJECTED=evil" }
        .to raise_error(described_class::UnsafeValue, /unsafe in a dotenv file/)
      expect(File.exist?(path)).to be false
    end

    it 'refuses shell metacharacters' do
      ['$(whoami)', '`id`', 'a b', 'quote"d'].each do |value|
        expect { env['TOKEN'] = value }.to raise_error(described_class::UnsafeValue)
      end
    end

    it 'accepts the characters real secrets and URLs are made of' do
      expect { env['TOKEN'] = 'sk_test_abc-123.XYZ+/=:@' }.not_to raise_error
      expect(env['TOKEN']).to eq('sk_test_abc-123.XYZ+/=:@')
    end
  end
end
