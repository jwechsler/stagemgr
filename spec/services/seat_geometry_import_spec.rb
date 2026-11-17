require 'rails_helper'

RSpec.describe SeatGeometryImport do
  # Eager: the venue factory builds a seat map (with seats) of its own, which
  # must exist before any Seat.count is taken.
  let!(:seat_map) { FactoryBot.create(:seat_map, seat_count: 0) }
  let(:header) { 'location,row,sequence,origin-x,origin-y,width,height,feature' }

  def csv_file(content)
    file = Tempfile.new(['geometry', '.csv'])
    file.binmode
    file.write(content)
    file.flush
    tempfiles << file
    file
  end

  def tempfiles
    @tempfiles ||= []
  end

  after { tempfiles.each(&:close!) }

  def import(content)
    described_class.new(seat_map, csv_file(content))
  end

  def seat(location)
    seat_map.seats.reload.find_by(location: location)
  end

  def geometry(seat)
    [seat.row, seat.seat_number, seat.origin_x, seat.origin_y, seat.width, seat.height, seat.feature]
  end

  describe '#call' do
    it 'imports every row of a well-formed file' do
      result = import(<<~CSV).call
        #{header}
        AA1,AA,1,10,20,5,6,
        AA2,AA,2,30,40,7,8,wheelchair
      CSV

      expect(result.imported_count).to eq(2)
      expect(result.skipped_rows).to be_empty
      expect(result.importable?).to be true
      expect(seat_map.seats.reload.count).to eq(2)
      expect(geometry(seat('AA1'))).to eq(['AA', 1, 10, 20, 5, 6, nil])
      expect(geometry(seat('AA2'))).to eq(['AA', 2, 30, 40, 7, 8, 'wheelchair'])
    end

    it 'imports columns given in a different order from the documented one' do
      result = import(<<~CSV).call
        feature,height,width,origin-y,origin-x,sequence,row,location
        wheelchair,8,7,40,30,2,BB,BB2
      CSV

      expect(result.imported_count).to eq(1)
      expect(geometry(seat('BB2'))).to eq(['BB', 2, 30, 40, 7, 8, 'wheelchair'])
    end

    it 'tolerates a UTF-8 byte order mark and whitespace around header names' do
      content = "﻿location , row,sequence ,origin-x,  origin-y,width,height,feature\nAA1,AA,1,10,20,5,6,\n"
      result = import(content).call

      expect(result.missing_headers).to be_empty
      expect(result.imported_count).to eq(1)
      expect(geometry(seat('AA1'))).to eq(['AA', 1, 10, 20, 5, 6, nil])
    end

    context 'when required headers are missing' do
      let(:existing) { FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA', seat_number: 1, origin_x: 1) }
      let(:importer) do
        import(<<~CSV)
          location,row,origin-x,origin-y,height,feature
          AA1,AA,99,99,5,
          AA2,AA,10,10,5,
        CSV
      end

      it 'is not importable and lists exactly the absent columns' do
        result = importer.check

        expect(result.importable?).to be false
        expect(result.missing_headers).to contain_exactly('sequence', 'width')
        expect(result.problem_message).to include('sequence', 'width')
      end

      it 'creates and changes no seats' do
        existing

        expect { importer.call }.not_to change(Seat, :count)
        expect(existing.reload.origin_x).to eq(1)
      end
    end

    it 'skips rows with a blank location, row or sequence and reports their file line numbers' do
      result = import(<<~CSV).call
        #{header}

        AA1,AA,1,10,10,5,5,
        ,AA,2,20,10,5,5,
        AA3,,3,30,10,5,5,
        AA4,AA,,40,10,5,5,
        AA5,AA,5,50,10,5,5,
      CSV

      expect(result.imported_count).to eq(2)
      expect(seat_map.seats.reload.pluck(:location)).to contain_exactly('AA1', 'AA5')
      expect(result.skipped_rows.map(&:line)).to eq([4, 5, 6])
      blank_location, blank_row, blank_sequence = result.skipped_rows
      expect(blank_location.reason).to match(/Location can't be blank/)
      expect(blank_location.location).to be_blank
      expect(blank_row.reason).to match(/Row can't be blank/)
      expect(blank_row.location).to eq('AA3')
      expect(blank_sequence.reason).to match(/Seat number can't be blank/)
      expect(blank_sequence.location).to eq('AA4')
    end

    it 'skips rows with an invalid zone and reports the zone rule' do
      result = import(<<~CSV).call
        #{header},zone
        AA1,AA,1,10,10,5,5,,*
        AA2,AA,2,20,10,5,5,,ABC
        AA3,AA,3,30,10,5,5,,B
      CSV

      expect(result.imported_count).to eq(1)
      expect(result.skipped_rows.map(&:location)).to eq(%w[AA1 AA2])
      expect(result.skipped_rows.map(&:line)).to eq([2, 3])
      expect(result.skipped_rows.map(&:reason)).to all(include('Zone must be 1-2 characters A-Z or 0-9'))
      expect(seat('AA3').zone).to eq('B')
    end

    it 'updates a seat whose location is already on the map rather than adding one' do
      existing = FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA', seat_number: 1, origin_x: 1)

      result = nil
      expect do
        result = import(<<~CSV).call
          #{header}
          AA1,AB,7,99,88,5,5,
        CSV
      end.not_to change(Seat, :count)

      expect(result.imported_count).to eq(1)
      expect(geometry(existing.reload)).to eq(['AB', 7, 99, 88, 5, 5, nil])
    end

    it 'leaves one seat with the later row when a location repeats in the file, counting it once' do
      result = import(<<~CSV).call
        #{header}
        AA1,AA,1,10,10,5,5,
        AA1,AA,1,77,66,5,5,
      CSV

      expect(result.imported_count).to eq(1)
      expect(seat_map.seats.reload.where(location: 'AA1').count).to eq(1)
      expect([seat('AA1').origin_x, seat('AA1').origin_y]).to eq([77, 66])
    end

    it 'keeps existing zones when the zone column is absent' do
      FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA', seat_number: 1, zone: 'B2')

      import(<<~CSV).call
        #{header}
        AA1,AA,1,10,10,5,5,
      CSV

      expect(seat('AA1').zone).to eq('B2')
    end

    it 'resets the zone to A when the zone column is present but blank' do
      FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA', seat_number: 1, zone: 'B2')

      result = import(<<~CSV).call
        #{header},zone
        AA1,AA,1,10,10,5,5,,
      CSV

      expect(result.imported_count).to eq(1)
      expect(seat('AA1').zone).to eq('A')
    end

    it 'imports nothing and reports a read error for malformed CSV' do
      result = nil
      expect do
        result = import(<<~CSV).call
          #{header}
          AA1,AA,1,10,10,5,5,
          "AA2,AA,2,20,10,5,5,
        CSV
      end.not_to change(Seat, :count)

      expect(result.read_error).to be_present
      expect(result.importable?).to be false
      expect(result.problem_message).to eq(result.read_error)
      expect(result.imported_count).to eq(0)
    end

    it 'reports a read error for an empty file' do
      result = import('').call

      expect(result.read_error).to include('empty')
      expect(result.importable?).to be false
      expect(seat_map.seats.reload).to be_empty
    end

    it 'treats a header-only file as importable with nothing imported' do
      result = import("#{header}\n").call

      expect(result.importable?).to be true
      expect(result.imported_count).to eq(0)
      expect(result.skipped_rows).to be_empty
      expect(result.summary_message).to include('Imported 0 seats')
    end
  end

  describe 'Result#skipped_message' do
    it 'lists at most MAX_LISTED_SKIPPED_ROWS rows followed by the number left over' do
      extra = 3
      rows = Array.new(described_class::MAX_LISTED_SKIPPED_ROWS + extra) { |i| "S#{i},,#{i + 1},1,1,1,1," }
      result = import("#{header}\n#{rows.join("\n")}\n").call
      message = result.skipped_message

      expect(result.skipped_rows.size).to eq(described_class::MAX_LISTED_SKIPPED_ROWS + extra)
      expect(message).to start_with("#{described_class::MAX_LISTED_SKIPPED_ROWS + extra} rows were skipped: ")
      expect(message.scan(/line \d+/).size).to eq(described_class::MAX_LISTED_SKIPPED_ROWS)
      expect(message).to end_with("and #{extra} more")
      expect(message).to include('line 2 (location S0)')
      expect(message).not_to include("location S#{described_class::MAX_LISTED_SKIPPED_ROWS}")
    end

    it 'is nil when nothing was skipped' do
      result = import("#{header}\nAA1,AA,1,10,10,5,5,\n").call

      expect(result.skipped_message).to be_nil
    end
  end

  describe '#check' do
    it 'does not change the database' do
      existing = FactoryBot.create(:seat, seat_map: seat_map, location: 'AA1', row: 'AA', seat_number: 1, origin_x: 1)
      importer = import(<<~CSV)
        #{header}
        AA1,AA,1,99,99,5,5,
        AA2,AA,2,20,10,5,5,
      CSV

      result = nil
      expect { result = importer.check }.not_to change(Seat, :count)

      expect(result.importable?).to be true
      expect(result.imported_count).to eq(0)
      expect(existing.reload.origin_x).to eq(1)
    end
  end
end
