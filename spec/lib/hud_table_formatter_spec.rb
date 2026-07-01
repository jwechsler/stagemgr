require 'rails_helper'
require 'hud_table_formatter'

RSpec.describe HudTableFormatter do
  let(:columns) do
    [
      { key: :code, header: 'Code', align: :left },
      { key: :sold, header: 'Sold', align: :right }
    ]
  end

  let(:rows) do
    [
      { code: 'ALLY0327', sold: '54' },
      { code: 'NOON0327', sold: '25' }
    ]
  end

  describe '.render' do
    it 'matches MySQL --table=true format' do
      result = HudTableFormatter.render(columns: columns, rows: rows)
      expect(result).to include('+----------+------+')
      expect(result).to include('| Code     | Sold |')
      expect(result).to include('| ALLY0327 |   54 |')
    end

    it 'renders left-aligned and right-aligned columns correctly' do
      result = HudTableFormatter.render(columns: columns, rows: rows)
      # Left-aligned: code padded on the right
      expect(result).to include('| ALLY0327 |')
      # Right-aligned: sold padded on the left
      expect(result).to include('|   54 |')
      expect(result).to include('|   25 |')
    end

    it 'includes a title above the table when provided' do
      result = HudTableFormatter.render(columns: columns, rows: rows, title: 'HOUSE COUNTS')
      lines = result.split("\n")
      expect(lines.first).to eq('HOUSE COUNTS')
      # The separator should immediately follow the title
      expect(lines[1]).to start_with('+')
    end

    it 'does not include a title line when not provided' do
      result = HudTableFormatter.render(columns: columns, rows: rows)
      expect(result.split("\n").first).to start_with('+')
    end

    it 'includes a footer below the table when provided' do
      footer_text = 'Generated Fri Mar 27 13:26:57 CDT 2026'
      result = HudTableFormatter.render(columns: columns, rows: rows, footer: footer_text)
      lines = result.split("\n")
      expect(lines.last).to eq(footer_text)
      # The line before the footer should be the closing separator
      expect(lines[-2]).to start_with('+')
    end

    it 'does not include a footer line when not provided' do
      result = HudTableFormatter.render(columns: columns, rows: rows)
      expect(result.split("\n").last).to start_with('+')
    end

    it 'auto-sizes column widths to fit both headers and data' do
      wide_columns = [
        { key: :name, header: 'name', align: :left },
        { key: :amount, header: 'Amount', align: :left }
      ]
      wide_rows = [
        { name: 'Morning, Noon, and Night', amount: '1,203.50' },
        { name: 'The Ally', amount: '4,803.80' }
      ]
      result = HudTableFormatter.render(columns: wide_columns, rows: wide_rows)
      # "Morning, Noon, and Night" is 24 chars; column width = 24 + 2 = 26
      expect(result).to include('+--------------------------+----------+')
      expect(result).to include('| Morning, Noon, and Night | 1,203.50 |')
    end

    it 'renders a header-only table when rows are empty' do
      result = HudTableFormatter.render(columns: columns, rows: [])
      lines = result.split("\n")
      # Should be: separator, header row, separator, closing separator — four lines
      expect(lines.length).to eq(4)
      expect(lines[0]).to start_with('+')
      expect(lines[1]).to include('| Code')
      expect(lines[2]).to start_with('+')
      expect(lines[3]).to start_with('+')
    end

    it 'sizes empty-row columns based on header width alone' do
      result = HudTableFormatter.render(columns: columns, rows: [])
      # "Code" is 4 chars, width = 6; "Sold" is 4 chars, width = 6
      expect(result).to include('+------+------+')
      expect(result).to include('| Code | Sold |')
    end

    it 'renders multiple rows correctly' do
      result = HudTableFormatter.render(columns: columns, rows: rows)
      expect(result).to include('| ALLY0327 |   54 |')
      expect(result).to include('| NOON0327 |   25 |')
    end
  end

  describe '.write_to_file' do
    it 'writes content to a tmp file then moves it atomically to the target' do
      dir = Dir.mktmpdir
      target = File.join(dir, 'output.txt')
      content = 'hello world'

      expect(FileUtils).to receive(:mv).with("#{target}.tmp", target).and_call_original

      HudTableFormatter.write_to_file(content, target)

      expect(File.read(target)).to eq(content)
      expect(File.exist?("#{target}.tmp")).to be false
    ensure
      FileUtils.rm_rf(dir)
    end

    it 'does not leave a .tmp file behind on success' do
      dir = Dir.mktmpdir
      target = File.join(dir, 'output.txt')

      HudTableFormatter.write_to_file('data', target)

      expect(File.exist?("#{target}.tmp")).to be false
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
