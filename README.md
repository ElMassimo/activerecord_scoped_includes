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

Customize which columns are loaded when eager loading [Active Record] associations.

```ruby
Album.includes(songs: -> { select(:id, :name) })
# SELECT "albums".* FROM "albums"
# SELECT "songs"."id", "songs"."name", "songs"."album_id" FROM "songs" WHERE "songs"."album_id" IN (1, 2)
```

## Why? 🤔

Selecting different columns when loading an association usually means defining
another association:

```ruby
class Album < ApplicationRecord
  has_many :songs
  has_many :song_titles, -> { select(:id, :name, :album_id) }, class_name: "Song"
end
```

This becomes cumbersome when different pages need different columns, and it's
easy to preload `song_titles` only to have a serializer call `songs`, loading
the records again.

With Scoped Includes, you can select columns in the `includes` call and keep
using `album.songs`, without defining extra associations.

## Features ⚡️

- Customize `includes`, `preload` and `eager_load` with a lambda or relation
- Select columns independently for nested associations
- Automatically selects the keys required to load associations
- Supports `has_many :through`, `belongs_to`, `strict_loading` and `Preloader`
- Load deferred columns per association when using [deferred_columns]

## Installation 💿

Add this line to your application's Gemfile:

```ruby
gem 'activerecord_scoped_includes'
```

And then run:

    $ bundle install

## Usage 🚀

### Selecting columns

You can pass a lambda or an Active Record relation to select columns for an association:

```ruby
Album.includes(songs: -> { select(:name, :track) })
Album.preload(songs: Song.select(:name, :track))
```

Lambdas are evaluated on the associated model, just like association scopes.
You can also reuse a relation:

```ruby
SONG_TITLES = Song.select(:name, :track)

Album.includes(songs: SONG_TITLES)
```

This also works with `eager_load`, or when `includes` uses a join:

```ruby
Album.eager_load(songs: -> { select(:name) })
Album.includes(songs: -> { select(:name) }).where(songs: { track: 1..3 })
```

When loading through a join, you can only select columns from the associated
table. SQL expressions such as `select("UPPER(name) AS name")` raise an `ArgumentError`.

### Primary and foreign keys

You don't need to include primary and foreign keys in your `select`. Scoped
Includes adds the keys Active Record needs to load the association, such as
`id` and `album_id` in the first example.

Without this, omitting the foreign key when preloading a `has_many` association
can leave it empty, without raising an error.

### Nested associations

To load nested associations, call `includes` on the relation:

```ruby
Artist.includes(albums: Album.select(:name).includes(songs: -> { select(:name) }))
```

You can combine this with regular includes:

```ruby
Song.includes(:playlist_entries, album: -> { select(:name) })
```

### Filtering and sorting

Scopes in `includes` support selecting columns, loading nested associations,
and enabling `strict_loading`, but not filtering, sorting, or limiting records.

For example, using `where` would leave `album.songs` with only some of its songs,
which could surprise other code using the association:

```ruby
Album.includes(songs: -> { where(track: 1) })
# ArgumentError: A scope in includes can only select columns or include associations, but this one uses where.
# To load only some of the records, define an association with that scope instead.
```

If you need to filter or sort records, define a separate association:

```ruby
has_many :opening_tracks, -> { where(track: 1) }, class_name: "Song"
```

### With deferred_columns

If you are using [deferred_columns], you can load deferred columns with `with_deferred`:

```ruby
Album.includes(songs: -> { with_deferred(:lyrics) })
```

This makes `lyrics` available when accessing `album.songs`.

If the association already uses `with_deferred`, the additional columns are
loaded along with those specified in the association:

```ruby
Album.eager_load(songs_with_lyrics: -> { with_deferred(:waveform) }) # lyrics and waveform
```

### Already loaded associations

As with regular preloading, associations that are already loaded are not reloaded.
Passing a scope won't fetch additional columns for those records.

## How it works 🔧

For `preload` and `includes` without joins, the library extends
`Preloader::Branch` to accept a scope per association. Nested includes become
child branches, and the scope is merged with the association's loading scope.

For `eager_load` and `includes` with joins, it extends `JoinDependency` to use
the columns selected by each scope instead of all columns from the joined table.

These are private Active Record APIs. The test suite runs against all supported
versions, including Rails `main`.

## Compatibility

- Ruby 3.1 or newer
- Active Record 7.2, 8.0, 8.1 and `main`
- Tested on SQLite and PostgreSQL

## Running tests 🧪

```sh
bundle install
bin/rspec
```

Integration tests with [deferred_columns] use a local checkout at
`../deferred_columns` if available, or the released gem otherwise.

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
