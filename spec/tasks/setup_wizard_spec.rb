require 'rails_helper'
require Rails.root.join('lib/tasks/setup/wizard')

# #prepare_database is stubbed rather than driven against a real database on
# purpose: the only way to exercise its interesting branch for real is to drop
# and reload a schema, and every database this suite can reach is one another
# example is using. What matters is the decision it makes.
RSpec.describe Setup::Wizard do
  subject(:wizard) { described_class.new(out: StringIO.new, input: StringIO.new) }

  describe '#prepare_database' do
    let(:migration_context) { instance_double(ActiveRecord::MigrationContext, needs_migration?: false) }

    before do
      allow(wizard).to receive(:create_database_if_absent)
      allow(ActiveRecord::Base.connection).to receive(:migration_context).and_return(migration_context)
      allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:load_schema)
    end

    # Replaying fifteen years of migrations into an empty database is slow, dies
    # on migrations that reference long-deleted constants, and rewrites
    # db/schema.rb. Load the schema instead.
    it 'loads db/schema.rb when the database has no schema_migrations table' do
      allow(wizard).to receive(:schema_loaded?).and_return(false)

      wizard.send(:prepare_database)

      expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:load_schema)
    end

    it 'leaves an already-initialized database alone' do
      allow(wizard).to receive(:schema_loaded?).and_return(true)

      wizard.send(:prepare_database)

      expect(ActiveRecord::Tasks::DatabaseTasks).not_to have_received(:load_schema)
    end

    it 'does not migrate when nothing is pending' do
      allow(wizard).to receive(:schema_loaded?).and_return(true)
      allow(Rake::Task).to receive(:[])

      wizard.send(:prepare_database)

      expect(Rake::Task).not_to have_received(:[]).with('db:migrate')
    end

    context 'with a pending migration' do
      let(:migrate_task) { instance_double(Rake::Task) }

      before do
        allow(wizard).to receive(:schema_loaded?).and_return(true)
        allow(migration_context).to receive(:needs_migration?).and_return(true)
        allow(Rake::Task).to receive(:[]).with('db:migrate').and_return(migrate_task)
      end

      it 'migrates without letting Rails rewrite the committed db/schema.rb' do
        dumping_during_migrate = nil
        allow(migrate_task).to receive(:invoke) do
          dumping_during_migrate = ActiveRecord::Base.dump_schema_after_migration
        end
        previously = ActiveRecord::Base.dump_schema_after_migration

        wizard.send(:prepare_database)

        expect(dumping_during_migrate).to be(false)
        expect(ActiveRecord::Base.dump_schema_after_migration).to be(previously)
      end

      it 'restores schema dumping even when the migration blows up' do
        allow(migrate_task).to receive(:invoke).and_raise(StandardError, 'boom')
        previously = ActiveRecord::Base.dump_schema_after_migration

        expect { wizard.send(:prepare_database) }.to raise_error(StandardError, 'boom')
        expect(ActiveRecord::Base.dump_schema_after_migration).to be(previously)
      end
    end
  end

  # db/seeds.rb runs on the first boot (setup:bootstrap seeds an empty
  # database), so by the time the wizard's own steps run there is already a
  # placeholder administrator with a published password and a Default theater
  # row named 'Theater 1'. Both steps below exist to replace those rather than
  # to leave them sitting beside the real ones.
  describe '#admin' do
    subject(:wizard) { described_class.new(out: StringIO.new, input: answers) }

    let(:answers) { StringIO.new("boss@example.org\nsupersecret\n") }

    # ADMIN_EMAIL/ADMIN_PASSWORD skip the prompts, and dotenv loads the
    # developer's own .env in this environment. Answer from `answers` regardless.
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ADMIN_EMAIL').and_return(nil)
      allow(ENV).to receive(:[]).with('ADMIN_PASSWORD').and_return(nil)
    end

    def seeded_admin
      User.create!(email: described_class::SEED_ADMIN_EMAIL, password: 'changeme',
                   is_administrator: true, is_box_office_user: false)
    end

    it 'renames the seeded placeholder instead of adding a second administrator' do
      placeholder = seeded_admin

      wizard.admin

      expect(User.where(is_administrator: true).pluck(:email)).to eq(['boss@example.org'])
      expect(placeholder.reload.email).to eq('boss@example.org')
    end

    it 'creates a new account when a real administrator already exists' do
      seeded_admin
      User.create!(email: 'someone@example.org', password: 'supersecret',
                   is_administrator: true, is_box_office_user: false)

      wizard.admin

      expect(User.where(is_administrator: true).pluck(:email))
        .to contain_exactly(described_class::SEED_ADMIN_EMAIL, 'someone@example.org', 'boss@example.org')
    end

    it 'updates the account that already owns the email' do
      existing = User.create!(email: 'boss@example.org', password: 'oldpassword',
                              is_administrator: false, is_box_office_user: true)

      wizard.admin

      expect(User.where(email: 'boss@example.org').count).to eq(1)
      expect(existing.reload).to be_is_administrator
    end
  end

  describe '#theater' do
    subject(:wizard) { described_class.new(out: StringIO.new, input: answers) }

    let(:answers) { StringIO.new("My House\nMain Stage\n") }

    # Theater.default_theater is the OLDEST Default row, so a second one would
    # be inert while db/seeds.rb's 'Theater 1' went on naming the house.
    it 'renames the existing default theater rather than creating a second one' do
      seeded = Theater.create!(name: 'Theater 1', theater_class: Theater::DEFAULT,
                               status: Theater::ACTIVE)

      wizard.theater

      expect(Theater.where(theater_class: Theater::DEFAULT).pluck(:name)).to eq(['My House'])
      expect(seeded.reload.name).to eq('My House')
      expect(Theater.default_theater.name).to eq('My House')
    end

    it 'creates a Default theater when there is none' do
      wizard.theater

      expect(Theater.default_theater).to have_attributes(name: 'My House', theater_class: Theater::DEFAULT)
    end
  end

  describe '#create_database_if_absent' do
    # DatabaseTasks.create prints and swallows several failures; without a probe
    # the wizard would announce "✓ created" and then collapse further down with
    # something unrelated-looking.
    it 'verifies the database is really usable after creating it' do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::NoDatabaseError)
      allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create)
      allow(ActiveRecord::Base).to receive(:establish_connection)

      expect { wizard.send(:create_database_if_absent) }.to raise_error(ActiveRecord::NoDatabaseError)
    end
  end
end
