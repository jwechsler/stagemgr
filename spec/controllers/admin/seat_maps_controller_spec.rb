require 'rails_helper'

RSpec.describe Admin::SeatMapsController, type: :controller do
  describe '#update_geometry' do
    let(:seat_map) { FactoryBot.create(:seat_map, seat_count: 0) }

    def import_csv(content)
      file = Tempfile.new(['geometry', '.csv'])
      file.write(content)
      file.flush
      controller.instance_variable_set(:@seat_map, seat_map)
      controller.send(:update_geometry, file)
    ensure
      file.close!
    end

    it 'imports zones when the optional zone column is present (normalized)' do
      import_csv(<<~CSV)
        location,row,sequence,origin-x,origin-y,width,height,feature,zone
        AA1,AA,1,10,10,5,5,,B
        AA2,AA,2,20,10,5,5,,a
      CSV

      expect(seat_map.seats.find_by(location: 'AA1').zone).to eq('B')
      expect(seat_map.seats.find_by(location: 'AA2').zone).to eq('A')
    end

    it 'preserves existing zones when the zone column is absent' do
      seat = FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA',
                                      seat_number: 1, zone: 'B2')

      import_csv(<<~CSV)
        location,row,sequence,origin-x,origin-y,width,height,feature
        AA1,AA,1,99,88,5,5,
      CSV

      seat.reload
      expect(seat.origin_x).to eq(99)
      expect(seat.origin_y).to eq(88)
      expect(seat.zone).to eq('B2')
    end
  end

  describe 'seat map editor endpoints' do
    let(:venue) { FactoryBot.create(:venue) }
    let(:seat_map) { FactoryBot.create(:seat_map, venue: venue, seat_count: 3) }

    before do
      user_double = double('User', id: 1, email: 'admin@example.com', role: User::ADMIN,
                                   theater_ids: [], is_box_office_user?: false,
                                   is_theater_user?: false, is_resident?: false, can?: true)
      allow(controller).to receive(:current_user).and_return(user_double)
      allow(controller).to receive(:authorize!).and_return(true)
    end

    def sold!(seat)
      FactoryBot.create(:performance).tap do |perf|
        SeatAssignment.create!(seat: seat, performance: perf, status: SeatAssignment::ASSIGNED,
                               order_uuid: SecureRandom.uuid)
      end
    end

    describe 'GET #index (datatable JSON)' do
      # 1x1 transparent PNG; blob dimensions are set directly in the example.
      let(:tiny_png) do
        Base64.decode64(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
        )
      end

      # The venue factory creates a seat map of its own, so pick our row out of
      # the response by the editor link in its label.
      def row_for(seat_map)
        response.parsed_body['data'].find { |row| row['label'].include?("/seat_maps/#{seat_map.id}/") }
      end

      def datatable_params
        column = { name: '', searchable: 'true', orderable: 'true', search: { value: '', regex: 'false' } }
        {
          venue_id: venue.id, draw: '1', start: '0', length: '10',
          search: { value: '', regex: 'false' },
          order: { '0' => { column: '0', dir: 'asc' } },
          columns: {
            '0' => column.merge(data: 'label'),
            '1' => column.merge(data: 'preview'),
            '2' => column.merge(data: 'actions')
          }
        }
      end

      it 'renders an SVG preview with seat circles when a base image is attached' do
        # Analysis needs ImageMagick in-process; set the dimensions directly.
        allow_any_instance_of(SeatMap).to receive(:save_image_dimensions)
        seat_map.base_image_map.attach(io: StringIO.new(tiny_png), filename: 'map.png', content_type: 'image/png')
        seat_map.base_image_map.blob.update!(metadata: { 'width' => 100, 'height' => 60, 'analyzed' => true })

        get :index, params: datatable_params, format: :json
        expect(response).to be_successful

        preview = row_for(seat_map)['preview']
        expect(preview).to include('<svg')
        expect(preview.scan('<circle').length).to eq(3)
      end

      it 'renders a blank preview when no base image is attached' do
        seat_map # create it, no attachment

        get :index, params: datatable_params, format: :json
        expect(row_for(seat_map)['preview']).to eq('')
      end
    end

    describe 'GET #show' do
      it 'redirects to the seat map editor' do
        get :show, params: { venue_id: venue.id, id: seat_map.id }
        expect(response).to redirect_to(editor_admin_venue_seat_map_path(venue, seat_map))
      end
    end

    describe 'GET #editor_data' do
      it 'returns seats with zone and deletable flags' do
        sold_seat = seat_map.seats.first
        sold!(sold_seat)

        get :editor_data, params: { venue_id: venue.id, id: seat_map.id }, format: :json
        expect(response).to be_successful
        body = response.parsed_body

        expect(body['seat_map']['id']).to eq(seat_map.id)
        expect(body['seats'].length).to eq(3)
        by_id = body['seats'].index_by { |s| s['id'] }
        expect(by_id[sold_seat.id]['deletable']).to be false
        (seat_map.seats - [sold_seat]).each do |seat|
          expect(by_id[seat.id]['deletable']).to be true
          expect(by_id[seat.id]['zone']).to eq('A')
        end
      end
    end

    describe 'POST #bulk_update_seats' do
      it 'creates, updates and maps client ids in one batch' do
        target = seat_map.seats.first
        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [
                                             { op: 'update', id: target.id, origin_x: 111, origin_y: 222, zone: 'B' },
                                             { op: 'create', client_id: 'new-1', location: 'ZZ1', row: 'ZZ',
                                               seat_number: 1, origin_x: 10, origin_y: 20, width: 8, height: 8, zone: 'B' }
                                           ] }

        expect(response).to be_successful
        body = response.parsed_body
        expect(body['status']).to eq('ok')

        target.reload
        expect([target.origin_x, target.origin_y, target.zone]).to eq([111, 222, 'B'])

        new_seat = seat_map.seats.find_by(location: 'ZZ1')
        expect(new_seat).to be_present
        expect(body['id_map']['new-1']).to eq(new_seat.id)
      end

      it 'rebuilds inventory for performances of productions using the map when a seat is added' do
        production = FactoryBot.create(:production, seat_map: seat_map, venue: venue)
        performance = FactoryBot.create(:performance, production: production)
        SeatAssignment.where(performance: performance).destroy_all
        seat_map.create_inventory_for_performance(performance)

        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [{ op: 'create', client_id: 'new-1', location: 'ZZ1', row: 'ZZ',
                                                     seat_number: 1, origin_x: 10, origin_y: 20, width: 8, height: 8 }] }

        expect(response).to be_successful
        new_seat = seat_map.seats.find_by(location: 'ZZ1')
        expect(SeatAssignment.where(performance: performance, seat: new_seat)).to exist
      end

      it 'allows geometry and zone updates on a sold seat' do
        sold_seat = seat_map.seats.first
        sold!(sold_seat)

        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [{ op: 'update', id: sold_seat.id, origin_x: 500, zone: 'C' }] }

        expect(response).to be_successful
        expect(sold_seat.reload.origin_x).to eq(500)
        expect(sold_seat.zone).to eq('C')
      end

      it 'deletes an unused seat' do
        seat = seat_map.seats.last
        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [{ op: 'delete', id: seat.id }] }

        expect(response).to be_successful
        expect(Seat.find_by(id: seat.id)).to be_nil
      end

      it 'refuses to delete a sold seat and rolls back the whole batch' do
        sold_seat = seat_map.seats.first
        other = seat_map.seats.last
        sold!(sold_seat)

        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [
                                             { op: 'update', id: other.id, origin_x: 777 },
                                             { op: 'delete', id: sold_seat.id }
                                           ] }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include(sold_seat.location)
        expect(Seat.find_by(id: sold_seat.id)).to be_present
        expect(other.reload.origin_x).not_to eq(777) # batch rolled back
      end

      it 'rejects a duplicate location with a validation error' do
        existing = seat_map.seats.first
        post :bulk_update_seats, format: :json,
                                 params: { venue_id: venue.id, id: seat_map.id,
                                           seats: [{ op: 'create', client_id: 'new-1', location: existing.location,
                                                     row: existing.row, seat_number: 99, origin_x: 1, origin_y: 1,
                                                     width: 8, height: 8 }] }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['status']).to eq('error')
      end
    end
  end
end
