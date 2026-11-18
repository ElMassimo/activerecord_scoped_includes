# frozen_string_literal: true

RSpec.describe 'Validating scopes in includes' do
  it 'rejects scopes that change which records are loaded' do
    message = 'A scope in includes can only select columns or include associations, but this one uses where. ' \
              'To load only some of the records, define an association with that scope instead.'

    expect { Album.includes(songs: -> { where(track: 1) }).to_a }.to raise_error(ArgumentError, message)
    expect { Album.preload(songs: Song.order(:name).limit(3)).to_a }.to raise_error(ArgumentError, /uses order, limit\./)
    expect { Album.eager_load(songs: Song.where(track: 1)).to_a }.to raise_error(ArgumentError, /uses where\./)
  end
end
