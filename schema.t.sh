diff -q schema.t.out <(cat schema{,.t}.sql | sqlite3 2>&1) && echo "Tests passed."
