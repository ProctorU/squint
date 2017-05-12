= SearchSemiStructuredData

DB searching inside columns containing semi-structured data like json, jsonb and hstore


Add to your Gemfile:

```
gem 'search_semi_structured_data'
```

Include it in your models:

```ruby
class Post < ActiveRecord::Base
  include SearchSemiStructuredData

end
```


Assuming a table with the following structure:
```
                                      Table "public.posts"
    Column    |            Type             |                     Modifiers
--------------+-----------------------------+----------------------------------------------------
 id           | integer                     | not null default nextval('posts_id_seq'::regclass)
 title        | character varying           |
 body         | character varying           |
 request_info | jsonb                       |
 properties   | hstore                      |
 created_at   | timestamp without time zone | not null
 updated_at   | timestamp without time zone | not null
Indexes:
    "posts_pkey" PRIMARY KEY, btree (id)
```


In your code use queries like:

* query's like
```
Post.where(properties: { referer: 'http://example.com/one' } ).count
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