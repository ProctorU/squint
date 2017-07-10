# Squint
[![All Contributors](https://img.shields.io/badge/all_contributors-5-orange.svg?style=flat-square)](#contributors)

DB searching inside columns containing semi-structured data like json, jsonb and hstore.
Compatible with the awesome [storext](https://github.com/G5/storext) gem.


Add to your Gemfile:

```
gem 'squint'
```

Include it in your models:

```ruby
class Post < ActiveRecord::Base
  include Squint
  # ...
end
```


Assuming a table with the following structure:
```
                                           Table "public.posts"
       Column              |            Type             |                     Modifiers
---------------------------+-----------------------------+----------------------------------------------------
 id                        | integer                     | not null default nextval('posts_id_seq'::regclass)
 title                     | character varying           |
 body                      | character varying           |
 request_info              | jsonb                       |
 properties                | hstore                      |
 storext_jsonb_attributes  | jsonb                       |
 storext_hstore_attributes | jsonb                       |
 created_at                | timestamp without time zone | not null
 updated_at                | timestamp without time zone | not null
Indexes:
    "posts_pkey" PRIMARY KEY, btree (id)
```

## Basic Usage
In your code use queries like:
```ruby
Post.where(properties: { referer: 'http://example.com/one' } )
# SELECT "posts".* FROM "posts" WHERE "posts"."properties"->'referer' = 'http://example.com/one'

Post.where(properties: { referer: nil } )
# SELECT "posts".* FROM "posts" WHERE "posts"."properties"->'referer' IS NULL

Post.where(properties: { referer: ['http://example.com/one',nil] } )
# SELECT "posts".* FROM "posts" WHERE ("posts"."properties"->'referer' = 'http://example.com/one'
#                                   OR "posts"."properties"->'referer' IS NULL)

Post.where(request_info: { referer: ['http://example.com/one',nil] } )
# SELECT "posts".* FROM "posts" WHERE ("posts"."request_info"->>'referer' = 'http://example.com/one'
#                                   OR "posts"."request_info"->>'referer' IS NULL)
```

Squint only operates on json, jsonb and hstore columns.   ActiveRecord
will throw a StatementInvalid exception like always if the column type is unsupported by
Squint.

```ruby
Post.where(:title => { not_there: "any value will do" } )
```

```
ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR:  missing FROM-clause entry for table "title"
LINE 1: SELECT COUNT(*) FROM "posts" WHERE "title"."not_there" = 'an...
                                           ^
: SELECT COUNT(*) FROM "posts" WHERE "title"."not_there" = 'any value will do'
```

## Performance
To get the most performance out searching jsonb/hstore attributes, add a GIN (preferred) or
GIST index to those columns.   Find out more
[here](https://www.postgresql.org/docs/9.5/static/textsearch-indexes.html)

TL;DR:

SQL: 'CREATE INDEX name ON table USING GIN (column);'

Rails Migration: `add_index(:table, :column_name, using: 'gin')`


## Storext attributes
Assuming the database schema above and a model like so:
```ruby
class Post < ActiveRecord::Base
  include Storext.model
  include Squint

  store_attribute :storext_jsonb_attributes, :zip_code, String, default: '90210'
  store_attribute :storext_jsonb_attributes, :friend_count, Integer, default: 0
end
```

Example using StoreXT with a default value:
```ruby
Post.where(storext_jsonb_attributes: { zip_code: '90210' } )
# -- jsonb
# SELECT "posts".* FROM "posts" WHERE ("posts"."storext_jsonb_attributes"->>'zip_code' = '90210' OR
#                                     (("posts"."storext_jsonb_attributes" ? 'zip_code') IS NULL OR
#                                      ("posts"."storext_jsonb_attributes" ? 'zip_code') = FALSE))
# -- hstore
# SELECT "posts".* FROM "posts" WHERE ("posts"."storext_hstore_attributes"->'zip_code' = '90210' OR
#                                     ((exist("posts"."storext_hstore_attributes", 'zip_code') = FALSE) OR
#                                       exist("posts"."storext_hstore_attributes", 'zip_code') IS NULL))
#
#
```
If (as in the example above) the default value for the StoreXT attribute is specified, then extra
checks for missing column ( `("posts"."storext_jsonb_attributes" ? 'zip_code') IS NULL` ) or
missing key ( `("posts"."storext_jsonb_attributes" ? 'zip_code') = FALSE)` ) are added

When non-default storext values are specified, these extra checks won't be added.

The Postgres SQL for jsonb and hstore is different.   No support for checking for missing `json`
columns exists, so don't use those with StoreXT + Squint

## Developing Squint

1. Thank you!
1. Clone the repository
1. `bundle`
1. `bundle exec rake --rakefile test/dummy/Rakefile db:setup` # create the db for tests
1. `bundle exec rake`   # run the tests
1. make your changes in a thoughtfully named branch
1. ensure good test coverage
1. submit a Pull Request

## Contributors

Thanks goes to these wonderful people ([emoji key](https://github.com/kentcdodds/all-contributors#emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
| [<img src="https://avatars0.githubusercontent.com/u/3933204?v=3" width="100px;"/><br /><sub>Justin Licata</sub>](http://justinlicata.com)<br />[💻](https://github.com/ProctorU/squint/commits?author=licatajustin "Code") [🎨](#design-licatajustin "Design") [📖](https://github.com/ProctorU/squint/commits?author=licatajustin "Documentation") [👀](#review-licatajustin "Reviewed Pull Requests") | [<img src="https://avatars2.githubusercontent.com/u/708692?v=3" width="100px;"/><br /><sub>Ryan T. Hosford</sub>](https://github.com/rthbound)<br />[💻](https://github.com/ProctorU/squint/commits?author=rthbound "Code") | [<img src="https://avatars2.githubusercontent.com/u/864581?v=3" width="100px;"/><br /><sub>Kevin Brown</sub>](https://github.com/chevinbrown)<br />[🎨](#design-chevinbrown "Design") [👀](#review-chevinbrown "Reviewed Pull Requests") | [<img src="https://avatars3.githubusercontent.com/u/19173815?v=3" width="100px;"/><br /><sub>Jay Wright</sub>](https://github.com/TheJayWright)<br />[👀](#review-TheJayWright "Reviewed Pull Requests") | [<img src="https://avatars2.githubusercontent.com/u/1741179?v=3" width="100px;"/><br /><sub>Andrew Fomera</sub>](http://andrewfomera.com)<br />[👀](#review-king601 "Reviewed Pull Requests") |
| :---: | :---: | :---: | :---: | :---: |
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification. Contributions of any kind welcome!