# Why inserts with Rel8 are expensive

## Repro

Simple run:

```
docker run --name rel8-demo   -e POSTGRES_PASSWORD=password   -e POSTGRES_DB=testdb   -p 5432:5432   -d postgres:latest
docker exec -it rel8-demo psql -U postgres -d testdb -c "CREATE TABLE files (content BYTEA NOT NULL);"
```

And then (tweak the IP address in `Main.hs`):

```
stack build --file-watch --exec rel8-check
```

## Output

Output:

```
Connected to database
encodeUtf8 ... => ditto
Text.pack sql => ditto
(show doc) => INSERT INTO "files" ("content")
VALUES
(CAST(E'\\x48656c6c6f2c20746869732069732073616d706c652066696c6520636f6e74656e7421' AS "bytea"))
File inserted successfully!
```

## Analysis

In other words, this function:

```haskell
-- Insert function using Rel8
insertFile :: BS.ByteString -> Hasql.Session ()
insertFile fContent = do
  let fileRecord = mkFileInsert fContent
  Hasql.statement () $ Rel8.run_ $ Rel8.insert $ Rel8.Insert
    { into = fileSchema
    , rows = Rel8.values [fileRecord]
    , onConflict = Rel8.Abort
    , returning = Rel8.NoReturning
    }
```

Hits this Rel8 function:

```haskell
makeRun :: Rows exprs a -> Statement exprs -> Hasql.Statement () a
makeRun rows statement = Hasql.Statement bytes params decode prepare
  where
    bytes = encodeUtf8 $ Text.pack sql
    params = Hasql.noParams
    prepare = False
    sql = show doc
    (doc, decode) = ppDecodeStatement ppSelect rows statement
```

Generates this SQL:

```sql
INSERT INTO "files" ("content")
VALUES
(CAST(E'\\x48656c6c6f2c20746869732069732073616d706c652066696c6520636f6e74656e7421'
AS "bytea"))
```

The following sequence of steps happens:

* Generate that SQL as a `Doc`
* Then `show` it to a `[Char]`
* Then `Text.pack` to a `Text`
* Then `encodeUtf8` to a `ByteString`

Then the whole thing is sent to the server as a giant query. :facepalm:
