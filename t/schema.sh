echo "My database file: $1"
if sqlite3 $1 < schema.sql; then
    diff t/schema.out <(sqlite3 $1 < t/schema.sql 2>&1) \
       && rm $1 && sqlite3 $1 < t/schema.sql \
       && TRSRDB_SQLITE_FILE=$1 perl t/schema.t \
       && rm -i $1
fi
