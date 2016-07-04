echo "My database file: $1"
if sqlite3 $1 < schema.sql; then
    diff t/schema.out <(sqlite3 $1 < t/schema.sql 2>&1)
fi
