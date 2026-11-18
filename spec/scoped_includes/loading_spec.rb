# frozen_string_literal: true

RSpec.describe 'Scopes in includes' do
  strategies = {
    'includes' => ->(scope) { Album.includes(songs: scope) },
    'preload' => ->(scope) { Album.preload(songs: scope) },
    'eager_load' => ->(scope) { Album.eager_load(songs: scope) },
    'includes with references' => ->(scope) { Album.includes(songs: scope).references(:songs) },
  }

  strategies.each do |strategy, build|
    describe strategy do
      { 'a lambda' => -> { with_deferred(:lyrics) }, 'a relation' => Song.with_deferred(:lyrics) }.each do |kind, scope|
        it "loads the columns that #{kind} opts into, into the association itself" do
          album = nil
          sql = queries { album = build.call(scope).where(name: 'Abraxas').to_a.sole }.join

          expect(sql).to include(column(:songs, :lyrics))
          expect(sql).not_to include('waveform')
          expect(album.association(:songs)).to be_loaded
          expect(album.songs.map(&:lyrics)).to eq(Catalog::ABRAXAS.map { |name, _| "Lyrics for #{name}" })
          expect(album.songs.first.has_attribute?(:waveform)).to be(false)
        end
      end

      it 'loads only the selected columns, and the keys to link the records' do
        album = build.call(-> { select(:name) }).where(name: 'Abraxas').to_a.sole

        expect(album.songs.map(&:name)).to eq(Catalog::ABRAXAS.map(&:first))
        expect(album.songs.first.attributes.keys - %w[album_id]).to match_array(%w[id name])
      end
    end
  end

  it 'nests the includes of the scope' do
    artist = nil
    statements = queries {
      artist = Artist.includes(albums: Album.with_deferred(:booklet).includes(songs: -> { with_deferred(:waveform) })).find_by!(name: 'Santana')
    }
    abraxas = artist.albums.find { |album| album.name == 'Abraxas' }

    expect(statements.size).to eq(3)
    expect(abraxas.liner_notes).to eq('Recorded at Wally Heider Studios, San Francisco.')
    expect(abraxas.songs.map(&:waveform)).to all(start_with('waveform-'))
    expect(abraxas.songs.first.has_attribute?(:lyrics)).to be(false)
  end

  it 'nests the includes of the scope when eager loading' do
    artist = nil
    albums = Album.with_deferred(:booklet).includes(songs: -> { with_deferred(:waveform) })
    query { artist = Artist.eager_load(albums:).where(name: 'Santana').to_a.sole }
    abraxas = artist.albums.find { |album| album.name == 'Abraxas' }

    expect(abraxas.liner_notes).to be_present
    expect(abraxas.songs.map(&:waveform)).to all(start_with('waveform-'))
    expect(abraxas.songs.first.has_attribute?(:lyrics)).to be(false)
  end

  it 'mixes with associations without a scope' do
    song = Song.includes(:playlist_entries, album: -> { with_deferred(:liner_notes) }).find_by!(name: 'Oye como va')

    expect(song.album.liner_notes).to be_present
    expect(song.album.has_attribute?(:cover_art)).to be(false)
    expect(song.association(:playlist_entries)).to be_loaded
  end

  it 'works for has_many :through, along with the opt-ins of the association scope' do
    %i[preload eager_load].each do |strategy|
      playlist = Playlist.public_send(strategy, songs: -> { with_deferred(:waveform) }).find_by!(name: 'Latin Rock')
      expect(playlist.songs.map(&:waveform)).to eq(%w[waveform-3 waveform-7])

      playlist = Playlist.public_send(strategy, songs_with_waveform: -> { with_deferred(:lyrics) }).find_by!(name: 'Latin Rock')
      expect(playlist.songs_with_waveform.map(&:waveform)).to eq(%w[waveform-3 waveform-7])
      expect(playlist.songs_with_waveform.map(&:lyrics)).to eq(['Lyrics for Oye como va', 'Lyrics for Samba pa ti'])
    end
  end

  it 'adds the keys to selects for belongs_to and has_many :through' do
    song = Song.preload(album: Album.select(:name)).find_by!(name: 'Oye como va')
    expect(song.album.attributes.keys).to match_array(%w[id name])

    playlist = Playlist.preload(songs: Song.select(:name)).find_by!(name: 'Latin Rock')
    expect(playlist.songs.map(&:name)).to eq(['Oye como va', 'Samba pa ti'])
    expect(playlist.songs.first.attributes.keys).to match_array(%w[id name])
  end

  it 'keeps strict_loading' do
    album = Album.strict_loading.includes(songs: -> { with_deferred(:lyrics) }).find_by!(name: 'Abraxas')

    expect(album.songs.first.lyrics).to eq('Lyrics for Singing Winds, Crying Beasts')
    expect { album.songs.first.album }.to raise_error(ActiveRecord::StrictLoadingViolationError)

    album = Album.includes(songs: -> { strict_loading }).find_by!(name: 'Abraxas')
    expect(album).not_to be_strict_loading
    expect(album.songs.first).to be_strict_loading
  end

  it 'works with the preloader' do
    playlists = Playlist.where(name: 'Latin Rock').to_a
    ActiveRecord::Associations::Preloader.new(records: playlists, associations: [{ songs: -> { with_deferred(:waveform) } }]).call
    expect(playlists.first.songs.map(&:waveform)).to eq(%w[waveform-3 waveform-7])
    expect(playlists.first.songs.first.has_attribute?(:lyrics)).to be(false)

    albums = Album.where(name: 'Abraxas').to_a
    ActiveRecord::Associations::Preloader.new(records: albums, associations: { songs: -> { select(:id, :name) } }).call
    expect(albums.first.songs.size).to eq(9)
    expect(albums.first.songs.first.attributes.keys).to match_array(%w[id name album_id])
  end

  it 'merges the scope with the scope of the preloader' do
    albums = Album.where(name: 'Abraxas').to_a
    associations = { songs: -> { with_deferred(:lyrics) } }
    ActiveRecord::Associations::Preloader.new(records: albums, associations:, scope: Song.with_deferred(:waveform)).call

    expect(albums.first.songs.first.lyrics).to eq('Lyrics for Singing Winds, Crying Beasts')
    expect(albums.first.songs.first.waveform).to eq('waveform-1')
  end

  it 'leaves associations without a scope as they were' do
    album = Album.preload(:songs).find_by!(name: 'Abraxas')
    expect(album.songs.first.has_attribute?(:lyrics)).to be(false)

    album = Album.eager_load(:songs_with_lyrics).find_by!(name: 'Abraxas')
    expect(album.songs_with_lyrics.first.has_attribute?(:lyrics)).to be(true)
  end
end
