# frozen_string_literal: true

RSpec.describe 'Scopes in eager_load' do
  it 'selects the columns of the scope, plus the primary key' do
    album = nil
    sql = query { album = Album.eager_load(songs: -> { select(:name) }).where(name: 'Abraxas').to_a.sole }

    expect(sql).to include(%("songs"."name" AS))
    expect(sql).to include(%("songs"."id" AS))
    expect(sql).not_to include(%("songs"."composer" AS))
    expect(album.songs.map(&:name)).to eq(Catalog::ABRAXAS.map(&:first))
  end

  it 'adds the opt-ins of the scope to those of the association scope' do
    album = nil
    sql = query { album = Album.eager_load(songs_with_lyrics: -> { with_deferred(:waveform) }).where(name: 'Abraxas').to_a.sole }

    expect(sql).to include(%("songs"."lyrics" AS), %("songs"."waveform" AS))
    expect(album.songs_with_lyrics.first.lyrics).to eq('Lyrics for Singing Winds, Crying Beasts')
    expect(album.songs_with_lyrics.first.waveform).to eq('waveform-1')
  end

  it 'loads every column for models without deferred columns' do
    playlist = PlaylistEntry.eager_load(playlist: -> { strict_loading }).find_by!(position: 1).playlist
    expect(playlist.attributes.keys).to eq(Playlist.column_names)
  end

  it 'rejects selects that are not columns of the table' do
    expect { Album.eager_load(songs: -> { select('UPPER(name) AS name') }).to_a }
      .to raise_error(ArgumentError, 'When eager loading, a scope in includes can only select columns of songs, got: UPPER(name) AS name')
    expect { Album.eager_load(songs: -> { select(Album.arel_table[:name]) }).to_a }
      .to raise_error(ArgumentError, /can only select columns of songs, got: albums.name/)
  end
end
