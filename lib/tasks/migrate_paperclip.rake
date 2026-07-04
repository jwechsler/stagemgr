namespace :migrate_paperclip do
  desc 'Updates Active Storage Blobs'
  task create_active_storage: :environment do
    class MigrateToActiveStorage
      require 'open-uri'

      def perform
        get_blob_id = 'LAST_INSERT_ID()'

        Rails.application.eager_load!
        @active_storage_blob_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
          INSERT INTO active_storage_blobs (
            active_storage_blobs.key, filename, content_type, metadata, byte_size, checksum, created_at
          ) VALUES (?, ?, ?, '{}', ?, ?, ?)
        SQL

        @active_storage_attachment_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
          INSERT INTO active_storage_attachments (
            name, record_type, record_id, blob_id, created_at
          ) VALUES (?, ?, ?, #{get_blob_id}, ?)
        SQL

        models = ActiveRecord::Base.descendants.reject(&:abstract_class?)

        ActiveRecord::Base.transaction do
          models.each do |model|
            attachments = model.column_names.map do |c|
              ::Regexp.last_match(1) if c =~ /(.+)_file_name$/
            end.compact

            next if attachments.blank?

            model.find_each.each do |instance|
              attachments.each do |attachment|
                puts "#{instance}, #{attachment}"
                next if instance.send(attachment).path.blank? || !File.exist?(instance.send(attachment).path)

                @active_storage_blob_statement.execute(
                  key(instance, attachment),
                  instance.send("#{attachment}_file_name"),
                  instance.send("#{attachment}_content_type"),
                  instance.send("#{attachment}_file_size"),
                  checksum(instance.send(attachment)),
                  instance.updated_at.iso8601
                )

                @active_storage_attachment_statement.execute(
                  attachment,
                  model.name,
                  instance.id,
                  instance.updated_at.iso8601
                )
              end
            end
          end
        end
      end

      private

      def key(instance, attachment)
        # SecureRandom.uuid
        # Alternatively:
        instance.send(attachment.to_s).path
      end

      def checksum(attachment)
        # local files stored on disk:
        url = attachment.path.to_s
        puts "checksum = #{url}"
        Digest::MD5.base64digest(File.read(url))

        # remote files stored on another person's computer:
        # url = attachment.url

        # Digest::MD5.base64digest(Net::HTTP.get(URI(url)))
      end
    end
    MigrateToActiveStorage.new.perform
  end

  desc 'Moves data to correct filestore'
  task migrate_data: :environment do
    class MigrateData
      def perform
        models = ActiveRecord::Base.descendants.reject(&:abstract_class?)

        models.each do |model|
          attachments = model.column_names.map do |c|
            ::Regexp.last_match(1) if c =~ /(.+)_file_name$/
          end.compact

          attachments.each do |attachment|
            migrate_data(attachment, model)
          end
        end
      end

      private

      def migrate_data(attachment, model)
        model.where.not("#{attachment}_file_name": nil).find_each do |instance|
          name = instance.send("#{attachment}_file_name")
          content_type = instance.send("#{attachment}_content_type")
          id = instance.id

          url = "https://s3.amazonaws.com/#{bucket}/uploads/#{attachment.pluralize}/#{id}/original/#{name}"
          File.exist?(instance.send(attachment).path)
          instance.send(attachment.to_sym).attach(
            io: open(url),
            filename: name,
            content_type: content_type
          )
        end
      end
    end
    puts 'Creating blobs in active storage from paperclip'
  end
end
