require 'csv'
###
#
# LglDonorImport: loads in an export file from Little Green Light (or other donor system), 
# with the following fields:
#
#   'External constituent ID': Stagemgr ID (optional, for quick matching)
#   'Pref. Email': Email address (optional, for quick matching)
#   'First Name': First name for customer matching
#   'Last Name': Last name for customer matching
#   'TG Tier Last Fiscal': Donor tier from previous fiscal year
#   'TG Tier This Fiscal': Donor tier in current fiscal year
#
# Records will be matched on ID, then email, then names and email for merging with existing records
# The donor_tier_updated_on datestamp will be updated for the record as well, to assist the house
# management report in pulling current donor information

class LglDonorImport < ImportIssuesReport

  LGL_DONOR_FIELDS = ['External Constituent Id', 'First Name', 'Last Name', 'Pref. Email', 'TG Tier Last Fiscal',
                      'TG Tier This Fiscal']
  @queue = :import

  # find address from import_row
  def self.find_address_from_import_row

  end

  def self.perform(filestore_id)
    filestore = FileStore.find(filestore_id)
    problems = nil
    headers = nil
    total = 0
    merged = 0
    first_name_idx = 0
    last_name_idx = 0
    full_name_idx = 0
    address1_idx = 0
    address2_idx = 0
    address3_idx = 0
    city_idx = 0
    state_idx = 0
    zip_idx = 0
    zip4_idx = 0
    email_idx = 0
    phone_idx = 0
    address_id_idx = 0
    last_fiscal_tier_idx = 0
    current_fiscal_tier_idx = 0
    filestore.notes = "Importing Donor Levels..."
    filestore.save
    CSV.foreach(filestore.path) do |row|
      if headers.nil? then
        _index = 0
        headers = Hash[row.map {|header| _index += 1; [header, _index]}]
        problems = ImportIssuesReport.new(LGL_DONOR_FIELDS, filestore.user.id)
        address_id_idx = headers['External constituent ID']
        first_name_idx = headers['First Name'] - 1
        last_name_idx = headers['Last Name'] - 1
        email_idx = headers['Pref. Email'] - 1
        last_fiscal_tier_idx = headers['TG Tier Last Fiscal'] - 1
        current_fiscal_tier_idx =  headers['TG Tier This Fiscal'] - 1
      else
        total += 1
        last_fiscal_tier = row[last_fiscal_tier_idx]
        current_fiscal_tier = row[current_fiscal_tier_idx]
        a = nil
        unless last_fiscal_tier.blank? && current_fiscal_tier.blank?
          begin
            a = Address.find(row[address_id_idx].to_i) unless row[address_id_idx].blank?
          rescue (ActiveRecord::RecordNotFound)
            begin
              a = Address.find_by_email(row[email_idx]) if !row[email_idx].blank?
            rescue ActiveRecord::RecordNotFound
              
            end
          end
          puts "Found record #{a.id}" unless a.nil?
          puts "Creating address record" if a.nil?
          a = Address.new if a.nil?
          a.first_name = row[first_name_idx]
          a.last_name = row[last_name_idx]
          a.full_name = a.first_name unless a.first_name.blank?
          a.full_name += a.full_name.blank? ?  a.last_name : " #{a.last_name}"  unless a.last_name.blank?
          a.email = row[email_idx] if a.email.blank?
          a.donor_tier_for_last_fiscal_year = last_fiscal_tier
          a.donor_tier_for_current_fiscal_year = current_fiscal_tier
          a.donor_tier_updated_on = Date.today
          merge_check = a.find_original
          merged += 1 if !merge_check.nil?
          begin
            unless merge_check.nil? then
              if a.id.nil? then
                # New record - save first, then merge into existing
                a.save!
                puts "Merging #{a.id} into #{merge_check.id}"
                merge_check.merge_and_purge(a)
                a = merge_check
              elsif a.id < merge_check.id then
                puts "Merging #{merge_check.id} into #{a.id}"
                a.merge_and_purge(merge_check)
              else
                puts "Merging #{a.id} into #{merge_check.id}"
                merge_check.merge_and_purge(a)
                a = merge_check
              end
            end
            a.save! unless a.id.nil?
            puts "Saved address #{a.id}"
          rescue ActiveRecord::RecordInvalid=>e
            data = headers.keys.map {|key| row[headers[key]]}
            problems.add_problem_row(row: data, message: e.message)
          end
          puts "Imported: #{row}"
        end
      end
    end
    filestore.notes = "Imported #{total} contacts, merged #{merged} as donors."
    filestore.save
    if problems.any_issues?
      fs = problems.create
      fs.save!
      ImportIssuesReport.notify_user_on_completion(fs) unless fs.nil?
    end
  end
end
