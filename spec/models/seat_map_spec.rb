require 'rails_helper'

RSpec.describe SeatMap, type: :model do
  context 'creation' do
    it 'can be assigned to a venue' do
      @venue = FactoryBot.create(:venue)
      seatmap = FactoryBot.create(:seat_map, venue: @venue)
      seatmap.venue = @venue
      seatmap.save
      expect(seatmap.venue).to eq(@venue)
      @venue.reload
      expect(@venue.seat_maps).to include(seatmap)
    end

    it 'can be assigned seats' do
      seatmap = FactoryBot.create(:seat_map, seat_count: 8)

      expect(seatmap.seats.count).to eq(8)
    end

    it 'can be assigned to a production in that venue' do
      seat_map = FactoryBot.create(:seat_map)
      production = FactoryBot.create(:production, venue: seat_map.venue)
      production.seat_map = seat_map
      expect(production.save).to be true
    end

    it 'cannot be assigned to a production in a different venue' do
      seat_map = FactoryBot.create(:seat_map)
      venue = FactoryBot.create(:venue)
      production = FactoryBot.create(:production, venue: venue)
      production.seat_map = seat_map
      expect(production.save).to be false
    end
  end

  context 'capacity logic' do
    it 'returns the count of seats' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 12)
      expect(seat_map.capacity).to eq(12)
    end

    it 'returns 0 when no seats exist' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 0)
      expect(seat_map.capacity).to eq(0)
    end

    it 'dynamically counts seats if seats are added later' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 5)
      expect(seat_map.capacity).to eq(5)

      # Add more seats
      FactoryBot.create_list(:seat, 3, seat_map: seat_map)
      expect(seat_map.capacity).to eq(8)
    end

    it 'updates capacity when seats are removed' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 10)
      expect(seat_map.capacity).to eq(10)

      # Remove some seats
      seat_map.seats.limit(3).destroy_all
      expect(seat_map.capacity).to eq(7)
    end
  end

  context 'inventory management' do
    before(:each) do
      @seat_map = FactoryBot.create(:seat_map)
    end

    it 'automatically creates seating inventory on performance save if necessary' do
      production = FactoryBot.create(:production, venue: @seat_map.venue)
      performance = FactoryBot.create(:performance, production: production)
      expect(performance.seat_assignments.count).to eq(0)
      production.seat_map = @seat_map
      production.save
      performance.reload
      performance.save
      expect(performance.seat_assignments.count).to eq(8)
    end
  end

  context 'image dimensions' do
    # Deliberately not square, so swapped width and height would be caught.
    def png_bytes(width = 120, height = 40)
      Vips::Image.black(width, height).write_to_buffer('.png')
    end

    def uploaded_png(bytes, filename = 'map.png')
      file = Tempfile.new([File.basename(filename, '.*'), File.extname(filename)])
      file.binmode
      file.write(bytes)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, 'image/png', true, original_filename: filename)
    end

    it 'records the pixel size of an image uploaded as a file when the seat map is created' do
      seat_map = FactoryBot.build(:seat_map, base_image_map: uploaded_png(png_bytes))

      expect(seat_map.save).to be true
      seat_map.reload
      expect([seat_map.original_width, seat_map.original_height]).to eq([120, 40])
    end

    it 'records the pixel size of an image attached as an io and stores the file intact' do
      bytes = png_bytes
      seat_map = FactoryBot.build(:seat_map)
      seat_map.base_image_map.attach(io: StringIO.new(bytes), filename: 'map.png', content_type: 'image/png')

      expect(seat_map.save).to be true
      seat_map.reload
      expect([seat_map.original_width, seat_map.original_height]).to eq([120, 40])
      expect(seat_map.base_image_map.download.b).to eq(bytes.b)
    end

    it 'records the new image size when the image on an existing seat map is replaced' do
      seat_map = FactoryBot.create(:seat_map, base_image_map: uploaded_png(png_bytes))

      expect(seat_map.update(base_image_map: uploaded_png(png_bytes(300, 75), 'bigger.png'))).to be true
      seat_map.reload
      expect([seat_map.original_width, seat_map.original_height]).to eq([300, 75])
    end

    it 'leaves the image metadata alone when the seat map is saved without a new image' do
      seat_map = FactoryBot.create(:seat_map, base_image_map: uploaded_png(png_bytes))
      blob = seat_map.reload.base_image_map.blob
      metadata_before = blob.metadata

      expect(seat_map.update(label: 'Renamed')).to be true
      expect(blob.reload.metadata).to eq(metadata_before)
      expect(seat_map.reload.base_image_map.blob).to eq(blob)
    end

    it 'marks the blob analyzed so Rails does not enqueue its own analysis' do
      expect(ActiveStorage::AnalyzeJob).not_to receive(:perform_later)

      seat_map = FactoryBot.create(:seat_map, base_image_map: uploaded_png(png_bytes))

      expect(seat_map.reload.base_image_map.blob).to be_analyzed
    end

    it 'refuses to save, with an error on the image, when the file cannot be read as an image' do
      seat_map = FactoryBot.build(:seat_map, base_image_map: uploaded_png('not an image', 'broken.png'))

      expect { expect(seat_map.save).to be false }.not_to raise_error
      expect(seat_map.errors[:base_image_map]).to be_present
      expect(seat_map).not_to be_persisted
    end

    it 'swaps width and height for a JPEG whose EXIF orientation turns it a quarter turn' do
      rotated = Vips::Image.black(120, 40).mutate { |image| image.set_type!(GObject::GINT_TYPE, 'orientation', 6) }
      seat_map = FactoryBot.build(:seat_map)
      seat_map.base_image_map.attach(io: StringIO.new(rotated.write_to_buffer('.jpg')), filename: 'map.jpg',
                                     content_type: 'image/jpeg')

      expect(seat_map.save).to be true
      seat_map.reload
      expect([seat_map.original_width, seat_map.original_height]).to eq([40, 120])
    end
  end

  context 'deletion' do
    it 'is refused while a production uses the map, but allowed for an unassigned map' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 2)
      production = FactoryBot.create(:production, venue: seat_map.venue, seat_map: seat_map)
      performance = FactoryBot.create(:performance, production: production)
      sold = SeatAssignment.find_or_initialize_by(seat: seat_map.seats.first, performance: performance)
      sold.update!(status: SeatAssignment::ASSIGNED, order_uuid: SecureRandom.uuid)

      expect(seat_map.destroy).to be false
      expect(SeatMap.exists?(seat_map.id)).to be true
      expect(seat_map.seats.count).to eq(2)
      expect(SeatAssignment.exists?(sold.id)).to be true

      unassigned = FactoryBot.create(:seat_map, seat_count: 2)
      expect(unassigned.destroy).to be_truthy
      expect(Seat.where(seat_map_id: unassigned.id)).to be_empty
    end
  end

  describe '#landscape?' do
    # 1x1 PNG; the dimensions that matter are the ones recorded on the blob.
    tiny_png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')

    let(:seat_map) { FactoryBot.build(:seat_map) }

    def with_dimensions(width, height)
      allow(seat_map).to receive_messages(original_width: width, original_height: height)
      seat_map
    end

    it 'is true when the map is wider than it is tall' do
      expect(with_dimensions(480, 80)).to be_landscape
    end

    it 'is false when the map is taller than it is wide' do
      expect(with_dimensions(300, 600)).not_to be_landscape
    end

    it 'is false when the map is square' do
      expect(with_dimensions(400, 400)).not_to be_landscape
    end

    it 'is false when no image is attached' do
      expect(seat_map.base_image_map).not_to be_attached
      expect(seat_map).not_to be_landscape
    end

    it 'reads the dimensions recorded on the attached image' do
      seat_map = FactoryBot.create(:seat_map, seat_count: 0)
      # Analysis needs MiniMagick; record the size on the blob directly.
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(tiny_png), filename: 'map.png',
                                                    content_type: 'image/png',
                                                    metadata: { identified: true, analyzed: true,
                                                                width: 480, height: 80 })
      ActiveStorage::Attachment.create!(name: 'base_image_map', record: seat_map, blob: blob)
      seat_map.reload

      expect(seat_map.original_width).to eq(480)
      expect(seat_map.original_height).to eq(80)
      expect(seat_map).to be_landscape

      blob.update!(metadata: blob.metadata.merge('width' => 80, 'height' => 480))
      expect(seat_map.reload).not_to be_landscape
    end
  end

  describe 'dimensions with no image attached' do
    let(:seat_map) { FactoryBot.build(:seat_map) }

    it 'reports a width and height of 0' do
      expect(seat_map.base_image_map).not_to be_attached
      expect(seat_map.original_width).to eq(0)
      expect(seat_map.original_height).to eq(0)
    end
  end

  describe '#png_image?' do
    # 1x1 PNG, and the leading bytes of a JFIF JPEG. ActiveStorage identifies
    # the content type from these bytes, so each blob carries a real type.
    png_bytes = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')
    jpeg_bytes = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9".b

    # Analysis needs MiniMagick; mark the blob analyzed so attaching skips it.
    def attach_image(seat_map, bytes, filename)
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: filename,
                                                    metadata: { identified: true, analyzed: true,
                                                                width: 1, height: 1 })
      ActiveStorage::Attachment.create!(name: 'base_image_map', record: seat_map, blob: blob)
      seat_map.reload
    end

    let(:seat_map) { FactoryBot.create(:seat_map, seat_count: 0) }

    it 'is true when the attached image is a PNG' do
      attach_image(seat_map, png_bytes, 'map.png')

      expect(seat_map.base_image_map.content_type).to eq('image/png')
      expect(seat_map).to be_png_image
    end

    it 'is false when the attached image is a JPEG' do
      attach_image(seat_map, jpeg_bytes, 'map.jpg')

      expect(seat_map.base_image_map.content_type).to eq('image/jpeg')
      expect(seat_map).not_to be_png_image
    end

    it 'goes by the content type, not the file name' do
      attach_image(seat_map, jpeg_bytes, 'map.png')

      expect(seat_map.base_image_map.content_type).to eq('image/jpeg')
      expect(seat_map).not_to be_png_image
    end

    it 'is false when no image is attached' do
      expect(seat_map.base_image_map).not_to be_attached
      expect(seat_map).not_to be_png_image
    end
  end
end
