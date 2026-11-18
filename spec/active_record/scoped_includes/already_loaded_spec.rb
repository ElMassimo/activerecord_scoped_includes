# frozen_string_literal: true

RSpec.describe 'Associations that are already loaded' do
  let(:album) { Album.find_by!(name: 'Abraxas') }

  it 'keeps the records they have, as Rails does' do
    album.songs.load

    statements = queries { ActiveRecord::Associations::Preloader.new(records: [album], associations: { songs: -> { select(:name) } }).call }

    expect(statements).to be_empty
    expect(album.songs.first.has_attribute?(:composer)).to be(true)
  end

  it 'raises when they lack the deferred columns the scope opts into' do
    album.songs.load

    expect { ActiveRecord::Associations::Preloader.new(records: [album], associations: { songs: -> { with_deferred(:lyrics) } }).call }
      .to raise_error(DeferredColumns::NotLoadedError, /\AAlbum#songs was already loaded without Song#lyrics/)
  end

  it 'loads those columns when deferred_columns reports instead of raising' do
    album.songs.load
    handler = DeferredColumns.on_not_loaded
    DeferredColumns.on_not_loaded = ->(error) {}

    statements = queries { ActiveRecord::Associations::Preloader.new(records: [album], associations: { songs: -> { with_deferred(:lyrics) } }).call }

    expect(statements).to contain_exactly(match(/SELECT "songs"."id", "songs"."lyrics" FROM "songs"/))
    expect(album.songs.map(&:lyrics)).to all(start_with('Lyrics for'))
  ensure
    DeferredColumns.on_not_loaded = handler
  end
end
