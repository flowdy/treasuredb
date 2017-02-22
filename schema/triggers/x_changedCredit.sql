CREATE TRIGGER x_changedCredit
    BEFORE UPDATE OF account, value ON Credit
    WHEN EXISTS (SELECT * FROM Transfer WHERE credId=NEW.credId)
     AND NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK)
BEGIN
    SELECT RAISE(ABORT, "Credit involved in transactions to revoke at first");
END;

