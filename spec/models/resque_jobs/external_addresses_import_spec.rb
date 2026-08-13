require 'rails_helper'

# External IDs are authoritative by default: a record already tagged with the
# row's External ID is updated in place. Some theaters reuse IDs for
# different patrons, so the "Refresh external IDs" option skips the ID lookup
# and matches by name/email only, retagging the matched record.
RSpec.describe ExternalAddressesImport do
  let(:user) { User.create!(email: 'importer@example.com', password: 'sekritsekrit') }
  let(:theater) { FactoryBot.create(:theater) }

  def header_row
    'ExternalId,FirstName,MiddleName,LastName,FullName,FirstName2,MiddleName2,LastName2,FullName2,' \
      'EmailAddress1,EmailAddress2,Phone,Address,Address2,City,StateCode,PostalCode,' \
      'Tag1,TagValue1,Tag2,TagValue2'
  end

  def filestore_for(csv)
    file_store = FileStore.new(user: user, worker: FileStore::IMPORT, notes: 'External contact import')
    file_store.datafile.attach(io: StringIO.new(csv), filename: 'contacts.csv', content_type: 'text/csv')
    file_store.save!
    file_store
  end

  def csv_row(external_id:, full_name:, email:)
    "#{header_row}\n#{external_id},,,,#{full_name},,,,,#{email},,,,,,,,,,,\n"
  end

  def tagged_address(full_name:, email:, external_id:)
    address = FactoryBot.create(:address, full_name: full_name, email: email)
    address.address_tags.create!(tag_label: AddressTag::EXTERNAL_ID, tag_value: external_id, theater: theater)
    address
  end

  def run(csv, refresh: false)
    described_class.perform(filestore_for(csv).id, theater.id, refresh)
  end

  describe 'default (external ID is authoritative)' do
    it 'updates the record already holding the External ID even when the name differs' do
      holder = tagged_address(full_name: 'Old Name', email: 'old@example.com', external_id: 'EXT-1')

      expect do
        run(csv_row(external_id: 'EXT-1', full_name: 'New Name', email: 'new@example.com'))
      end.not_to change(Address, :count)

      expect(holder.reload.full_name).to eq('New Name')
      expect(holder.email).to eq('new@example.com')
    end

    it 'falls back to name/email dedup when no record holds the External ID' do
      existing = FactoryBot.create(:address, full_name: 'Casey Patron', email: 'casey@example.com')

      expect do
        run(csv_row(external_id: 'EXT-9', full_name: 'Casey Patron', email: 'casey@example.com'))
      end.not_to change(Address, :count)

      expect(existing.reload.external_id([theater.id])).to eq('EXT-9')
    end

    it 'still works for jobs queued with the two-argument signature' do
      expect do
        described_class.perform(
          filestore_for(csv_row(external_id: 'EXT-2', full_name: 'Fresh Person', email: 'fresh@example.com')).id,
          theater.id
        )
      end.to change(Address, :count).by(1)
    end
  end

  describe 'with refresh_external_ids (theater reused its IDs)' do
    it 'ignores the stale ID holder and matches by name/email, retagging the match' do
      stale_holder = tagged_address(full_name: 'Different Person', email: 'different@example.com',
                                    external_id: 'EXT-1')
      same_person = FactoryBot.create(:address, full_name: 'Casey Patron', email: 'casey@example.com')

      run(csv_row(external_id: 'EXT-1', full_name: 'Casey Patron', email: 'casey@example.com'), refresh: true)

      # The stale holder is a different patron and must not absorb the row.
      expect(stale_holder.reload.full_name).to eq('Different Person')
      expect(same_person.reload.external_id([theater.id])).to eq('EXT-1')
    end

    it 'creates a fresh record when nothing matches by name/email' do
      tagged_address(full_name: 'Different Person', email: 'different@example.com', external_id: 'EXT-1')

      expect do
        run(csv_row(external_id: 'EXT-1', full_name: 'Brand New', email: 'brand.new@example.com'), refresh: true)
      end.to change(Address, :count).by(1)

      expect(Address.find_by(full_name: 'Brand New').external_id([theater.id])).to eq('EXT-1')
    end
  end
end
