<h1 align="center">
Scoped Includes
<p align="center">
<a href="https://github.com/ElMassimo/activerecord_scoped_includes/actions"><img alt="Build Status" src="https://github.com/ElMassimo/activerecord_scoped_includes/workflows/build/badge.svg"/></a>
<a href="https://github.com/ElMassimo/activerecord_scoped_includes/blob/main/LICENSE.txt"><img alt="License" src="https://img.shields.io/badge/license-MIT-428F7E.svg"/></a>
</p>
</h1>

[Active Record]: https://guides.rubyonrails.org/active_record_basics.html
[deferred_columns]: https://github.com/ElMassimo/deferred_columns
[mongoid_includes]: https://github.com/ElMassimo/mongoid_includes
[nested_select]: https://github.com/alekseyl/nested_select
[Sequel]: https://sequel.jeremyevans.net/rdoc/files/doc/advanced_associations_rdoc.html
[Issues]: https://github.com/ElMassimo/activerecord_scoped_includes/issues

Choose the columns an [Active Record] association loads, right where you include it.

```ruby
Album.includes(songs: -> { select(:id, :name) })
# SELECT "albums".* FROM "albums"
# SELECT "songs"."id", "songs"."name", "songs"."album_id" FROM "songs" WHERE "songs"."album_id" IN (1, 2)
```

The records load into the association itself, so `album.songs` has them, and code that reads it doesn't need to know which columns were loaded or under which name.

## Why? 🤔

To load an association with different columns, Rails needs another association:

```ruby
class Album < ApplicationRecord
  has_many :songs
  has_many :song_titles, -> { select(:id, :name, :album_id) }, class_name: "Song"
end
```

Each variant needs a name, and the code that reads the records has to pick the right one. When a page loads one variant and a component reads the other, the same records are loaded twice.

This library lets the query decide how the association is loaded, in the same `includes` call that loads it.

## Features ⚡️

- A scope as the value of an association, in `includes`, `preload` and `eager_load`
- Accepts a lambda, as in association scopes, or a relation
- Nested includes go inside the scope, so each association keeps its own shape
- Adds the keys that link records to their owners, which a `select` can easily leave out
- Works with `has_many :through`, `belongs_to`, `strict_loading` and `Preloader`
- Works with [deferred_columns], to opt into deferred columns per association

## Installation 💿

Add this line to your application's Gemfile:

```ruby
gem 'activerecord_scoped_includes'
```

And then run:

    $ bundle install

## Usage 🚀

### Selecting columns

Pass a scope as the value of an association:

```ruby
Album.includes(songs: -> { select(:name, :track) })
Album.preload(songs: Song.select(:name, :track))
```

A lambda is evaluated on the associated model, like an association scope, while a relation can be built anywhere and reused:

```ruby
SONG_TITLES = Song.select(:name, :track)

Album.includes(songs: SONG_TITLES)
```

It works the same with `eager_load`, and with `includes` when it eager loads:

```ruby
Album.eager_load(songs: -> { select(:name) })
Album.includes(songs: -> { select(:name) }).where(songs: { track: 1..3 })
```

When eager loading, the scope can only select columns of the table, so `select("UPPER(name) AS name")` raises an `ArgumentError`.

### Keys

A select doesn't need to list the keys that link each record to its owner, such as `album_id` above.

In plain Rails, leaving them out of an association scope loads no records, without raising. This library adds them to the select.

### Nesting includes

Include associations of the scoped association inside the scope:

```ruby
Artist.includes(albums: Album.select(:name).includes(songs: -> { select(:name) }))
```

Associations without a scope can be mixed in as usual:

```ruby
Song.includes(:playlist_entries, album: -> { select(:name) })
```

### Only the shape, not the records

A scope can select columns, include associations, and enable `strict_loading`.

It can't filter or sort the records, since the association would then hold only some of its records, and other code reading it would get a partial list:

```ruby
Album.includes(songs: -> { where(track: 1) })
# ArgumentError: A scope in includes can only select columns or include associations, but this one uses where.
# To load only some of the records, define an association with that scope instead.
```

Define an association for those instead, as usual:

```ruby
has_many :opening_tracks, -> { where(track: 1) }, class_name: "Song"
```

### With deferred_columns

The scope can opt into the columns that [deferred_columns] leaves out:

```ruby
Album.includes(songs: -> { with_deferred(:lyrics) })
```

This loads the lyrics into `album.songs`, instead of a separate `songs_with_lyrics` association. The opt-ins add up with those of the association scope:

```ruby
Album.eager_load(songs_with_lyrics: -> { with_deferred(:waveform) }) # lyrics and waveform
```

### Associations that are already loaded

Like Rails, the preloader keeps the records of an association that is already loaded, so their columns stay as they were.

## How it works 🔧

`includes` and `preload` build a tree of associations with `Preloader::Branch`. When the value of an association is a scope, its nested includes become the children of the branch, and the rest of the scope is merged into the scope of the loader, the same way `Preloader.new(scope:)` applies a scope to every association.

`eager_load` builds a `JoinDependency` instead, which selects the column names of each joined model. When the association has a scope, those are the columns its `SELECT` would list, so selects and opt-ins from other libraries apply as well.

Both are private APIs of Active Record, so the library is tested against every supported version, including `main`.

## Compatibility

- Ruby 3.1 or newer
- Active Record 7.2, 8.0, 8.1 and `main`
- Tested on SQLite and PostgreSQL

## Running tests 🧪

The tests use [deferred_columns] from a sibling folder:

```sh
git clone https://github.com/ElMassimo/deferred_columns ../deferred_columns
bundle install
bin/rspec
```

To run the tests against a specific version of Rails, set `BUNDLE_GEMFILE` to one of the files in `gemfiles`:

```sh
BUNDLE_GEMFILE=gemfiles/Gemfile-rails.7.2.x bundle install
BUNDLE_GEMFILE=gemfiles/Gemfile-rails.7.2.x bin/rspec
```

The tests run on an in-memory SQLite database by default. To run them on PostgreSQL, set `DATABASE_URL`:

```sh
createdb activerecord_scoped_includes_test
DATABASE_URL=postgres:///activerecord_scoped_includes_test bin/rspec
```

## Acknowledgements 🙏

- [mongoid_includes], whose `with:` option customizes an included association in Mongoid
- [nested_select], which selects columns of preloaded associations with `select(songs: [:name])`
- [Sequel], whose `eager` takes a proc per association to customize its dataset

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
