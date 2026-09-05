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
