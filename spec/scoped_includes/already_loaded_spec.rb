# frozen_string_literal: true

RSpec.describe 'Associations that are already loaded' do
  let(:album) { Album.find_by!(name: 'Abraxas') }

  it 'keeps the records they have, as Rails does' do
    album.songs.load

    statements = queries { ActiveRecord::Associations::Preloader.new(records: [album], associations: { songs: -> { select(:name) } }).call }

    expect(statements).to be_empty
    expect(album.songs.first.has_attribute?(:composer)).to be(true)
  end

  it 'loads the columns the scope opts into' do
    pending 'deferred_columns checks preload scopes with opt-ins against associations that are already loaded'
    album.songs.load

    ActiveRecord::Associations::Preloader.new(records: [album], associations: { songs: -> { with_deferred(:lyrics) } }).call

    expect(album.songs.map(&:lyrics)).to all(start_with('Lyrics for'))
  end
end
