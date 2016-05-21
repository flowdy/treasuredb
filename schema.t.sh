diff -q <(cat schema{,.t}.sql | sqlite3 2>&1) - <<OUT && echo "Tests passed."
Balance of Club's account: 0 -23450
Balance of john's account: 7200 -7200
Balance of Club's account: 7200 -23450
Balance of john's account: 0 0
Balance of Club's Account: 0 -16250
Balance of alex's Account: 7200 0
Error: near line 242: paid is set and adjusted automatically according to added Transfer records
Error: near line 243: Debt is involved in transfers to revoke at first
Error: near line 244: FOREIGN KEY constraint failed
Balance of Club's Account: 7200 0
Balance of alex's Account: 0 0
Balance of Club's Account: 0 -16250
Balance of alex's Account: 7200 0
OUT
