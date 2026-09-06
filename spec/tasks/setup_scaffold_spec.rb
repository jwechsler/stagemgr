require 'rails_helper'
require 'tmpdir'
require Rails.root.join('lib/tasks/setup/scaffold')

# Scaffold is deliberately root-injectable so these examples run against a
# throwaway directory instead of the real checkout — the class's whole job is
# writing gitignored files, and the developer's own config must never be a
# casualty of the suite.
RSpec.describe Setup::Scaffold do
  around do |example|
    Dir.mktmpdir('scaffold-spec') do |dir|
      @root = dir
      example.run
    end
  end

  attr_reader :root

  subject(:scaffold) { described_class.new(root: root, out: StringIO.new) }

  def write(relative_path, contents = "# template\n")
    absolute = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, contents)
    absolute
  end

  def read(relative_path)
    File.read(File.join(root, relative_path))
  end

  def exist?(relative_path)
    File.exist?(File.join(root, relative_path))
  end

  describe '#config' do
    it 'copies every config template and the dotenv template' do
      write('config/database.yml.example', "adapter: mysql2\n")
      write('config/server.yml.example', "all:\n")
      write('.env.example', "RAILS_ENV=development\n")

      result = scaffold.config

      expect(result[:created]).to contain_exactly('config/database.yml', 'config/server.yml', '.env')
      expect(read('config/database.yml')).to eq("adapter: mysql2\n")
      expect(read('.env')).to eq("RAILS_ENV=development\n")
    end

    it 'never overwrites a file that already exists' do
      write('config/server.yml.example', "all:\n  app_name: Template\n")
      write('config/server.yml', "all:\n  app_name: Mine\n")

      result = scaffold.config

      expect(result[:created]).to be_empty
      expect(result[:skipped]).to eq(['config/server.yml'])
      expect(read('config/server.yml')).to include('Mine')
    end

    it 'leaves credentials templates alone (they are documentation, not a target file)' do
      write('config/credentials/credentials.yml.example', "secret_key_base: xxx\n")

      scaffold.config

      expect(exist?('config/credentials/credentials.yml')).to be false
    end

    it 'reports nothing to do in an empty checkout' do
      expect(scaffold.config).to eq(created: [], skipped: [])
    end
  end

  describe '#site' do
    before { write('sites/example/views/shared/_house_thanks_line.html.haml', "%p Thanks\n") }

    it 'copies the example theme to the requested slug' do
      expect(scaffold.site('mytheater')[:site]).to eq(:created)
      expect(read('sites/mytheater/views/shared/_house_thanks_line.html.haml')).to eq("%p Thanks\n")
    end

    it 'never overwrites an existing theme directory' do
      write('sites/mytheater/views/shared/_house_thanks_line.html.haml', "%p Mine\n")

      expect(scaffold.site('mytheater')[:site]).to eq(:present)
      expect(read('sites/mytheater/views/shared/_house_thanks_line.html.haml')).to eq("%p Mine\n")
    end

    it 'fails with an actionable message when there is no example theme to copy' do
      FileUtils.rm_rf(File.join(root, 'sites'))

      expect { scaffold.site('mytheater') }
        .to raise_error(described_class::Error, %r{sites/example is missing})
    end

    it 'rejects a slug that could escape the sites directory' do
      expect { scaffold.site('../../etc') }.to raise_error(described_class::Error, /invalid site slug/)
      expect { scaffold.site('My Theater') }.to raise_error(described_class::Error, /invalid site slug/)
    end

    context 'with a server.yml present' do
      before { write('config/server.yml', "all:\n  app_name: \"StageMgr\"\n\ndevelopment:\n  root_url: x\n") }

      it 'inserts site_theme as the first key of the all block' do
        expect(scaffold.site('mytheater')[:server_yml]).to eq(:inserted)
        expect(read('config/server.yml'))
          .to eq("all:\n  site_theme: mytheater\n  app_name: \"StageMgr\"\n\ndevelopment:\n  root_url: x\n")
      end

      it 'is idempotent — a second run leaves the file untouched' do
        scaffold.site('mytheater')
        before_second_run = read('config/server.yml')

        expect(scaffold.site('mytheater')[:server_yml]).to eq(:already_set)
        expect(read('config/server.yml')).to eq(before_second_run)
      end

      it 'leaves an existing site_theme alone rather than adding a second one' do
        write('config/server.yml', "all:\n  site_theme: original\n")

        expect(scaffold.site('mytheater')[:server_yml]).to eq(:already_set)
        expect(read('config/server.yml')).to eq("all:\n  site_theme: original\n")
      end
    end

    it 'still copies the theme when server.yml has not been generated yet' do
      expect(scaffold.site('mytheater')).to eq(site: :created, server_yml: :no_server_yml)
    end

    it 'does not guess where to put the key when there is no all block' do
      write('config/server.yml', "development:\n  root_url: x\n")

      expect(scaffold.site('mytheater')[:server_yml]).to eq(:no_all_block)
      expect(read('config/server.yml')).to eq("development:\n  root_url: x\n")
    end
  end

  describe '#secret_key_base' do
    it 'fills in a blank value' do
      write('.env', "RAILS_ENV=development\nSECRET_KEY_BASE=\nREDIS_URL=redis://x\n")

      expect(scaffold.secret_key_base).to eq(:generated)
      expect(read('.env')).to match(/^SECRET_KEY_BASE=[0-9a-f]{128}$/)
      expect(read('.env')).to include('REDIS_URL=redis://x')
    end

    it 'leaves an existing value alone' do
      write('.env', "SECRET_KEY_BASE=alreadyset\n")

      expect(scaffold.secret_key_base).to eq(:present)
      expect(read('.env')).to eq("SECRET_KEY_BASE=alreadyset\n")
    end

    it 'creates .env when it does not exist' do
      expect(scaffold.secret_key_base).to eq(:generated)
      expect(read('.env')).to match(/\ASECRET_KEY_BASE=[0-9a-f]{128}\n\z/)
    end

    it 'ignores a commented-out assignment' do
      write('.env', "# SECRET_KEY_BASE=old\n")

      expect(scaffold.secret_key_base).to eq(:generated)
      expect(read('.env')).to match(/^# SECRET_KEY_BASE=old$/)
      expect(read('.env')).to match(/^SECRET_KEY_BASE=[0-9a-f]{128}$/)
    end
  end
end
