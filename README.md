# SearchSemiStructuredData

DB searching inside columns containing semi-structured data like json, jsonb and hstore.
Compatible with the awesome [storext](https://github.com/G5/storext) gem.


Add to your Gemfile:

```
gem 'search_semi_structured_data'
```

Include it in your models:

```ruby
class Post < ActiveRecord::Base
  include SearchSemiStructuredData
  # ...
end
```


Assuming a table with the following structure:
```
                                      Table "public.posts"
       Column       |            Type             |                     Modifiers
--------------------+-----------------------------+----------------------------------------------------
 id                 | integer                     | not null default nextval('posts_id_seq'::regclass)
 title              | character varying           |
 body               | character varying           |
 request_info       | jsonb                       |
 properties         | hstore                      |
 storext_attributes | jsonb                       |
 created_at         | timestamp without time zone | not null
 updated_at         | timestamp without time zone | not null
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

SearchSemiStructuredData only operates on json, jsonb and hstore columns.   ActiveRecord
will throw a StatementInvalid exception like always if the column type is unsupported by
SearchSemiStructuredData.

```ruby
Post.where(:title => { not_there: "any value will do" } )
```

```
ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR:  missing FROM-clause entry for table "title"
LINE 1: SELECT COUNT(*) FROM "posts" WHERE "title"."not_there" = 'an...
                                           ^
: SELECT COUNT(*) FROM "posts" WHERE "title"."not_there" = 'any value will do'
```

## Storext attributes
Assuming the database schema above and a model like so:
```ruby
class Post < ActiveRecord::Base
  include Storext.model
  include SearchSemiStructuredData

  store_attribute :storext_attributes, :zip_code, String, default: '90210'
  store_attribute :storext_attributes, :friend_count, Integer, default: 0
end
```

Example using default value:
```ruby
Post.where(storext_attributes: { zip_code: '90210' } )
# SELECT "posts".* FROM "posts" WHERE ("posts"."storext_attributes"->>'zip_code' = '90210'
#                                   OR "posts"."storext_attributes"->>'zip_code' IS NULL)
```
