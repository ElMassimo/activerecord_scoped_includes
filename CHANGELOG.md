# Changelog

## 0.0.2 (2026-11-25)

- Load the associations included inside a lambda, which were ignored and then loaded lazily.
- Add the keys that nested associations need to scopes that select columns, such as the foreign key of a `belongs_to`.

## 0.0.1 (2026-11-18)

- Initial release: a scope as the value of an association in `includes`, `preload` and `eager_load`, as a lambda or a relation.
- Scopes can select columns, include associations and enable `strict_loading`, and raise an `ArgumentError` for anything that filters or sorts records.
- Add the keys that link records to their owners to scopes that select columns.
- Supports Active Record 7.2, 8.0, 8.1 and main.
