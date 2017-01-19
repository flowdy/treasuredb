setup_database() {
    cat schema/{tables.sql,*/*} | sqlite3 $1
}

echo "My database file: $1"
if setup_database $1; then
    diff t/schema.out <(sqlite3 $1 < t/schema.sql 2>&1) \
       && rm $1 && setup_database $1 \
       && TRSRDB_SQLITE_FILE=$1 perl t/schema.t \
       && rm -i $1
fi
