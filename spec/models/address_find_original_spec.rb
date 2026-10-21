# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Address, '#find_original' do
  def address(full_name, email = 'x@example.com')
    FactoryBot.create(:address, full_name: full_name, email: email)
  end

  it 'matches a record whose first name differs only by a middle initial' do
    keeper = address('Alicia Senior-Saywell')
    newer = address('Alicia M Senior-Saywell')

    expect(newer.find_original).to eq(keeper)
  end

  it 'ignores last-name case' do
    keeper = address('Alicia Senior-Saywell')
    newer = address('alicia M senior-saywell')

    expect(newer.find_original).to eq(keeper)
  end

  it 'does not match a different first name with the same last name and email' do
    address('Joyce Penniston')
    newer = address('John Penniston')

    expect(newer.find_original).to be_nil
  end

  it 'a couple record matches the first-named partner only' do
    john = address('John Penniston')
    couple = address('John and Joyce Penniston')
    joyce = address('Joyce Penniston')

    expect(couple.find_original).to eq(john)
    expect(joyce.find_original).to be_nil
  end

  it 'returns the lowest earlier id' do
    lowest = address('Alicia Senior-Saywell')
    address('Alicia B. Senior-Saywell')
    newest = address('Alicia M Senior-Saywell')

    expect(newest.find_original).to eq(lowest)
  end

  it 'never returns a higher id' do
    lower = address('Alicia Senior-Saywell')
    address('Alicia M Senior-Saywell')

    lower.full_name = 'Alicia Q Senior-Saywell'
    expect(lower.find_original).to be_nil
  end
end
