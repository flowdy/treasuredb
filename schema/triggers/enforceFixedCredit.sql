CREATE TRIGGER enforceFixedCredit
    BEFORE UPDATE OF account, value ON Credit
    WHEN EXISTS (SELECT * FROM Transfer WHERE credId=NEW.credId)
     AND NOT EXISTS (SELECT * FROM __DO_NOT_MANIPULATE__trigger_memory)
BEGIN
    SELECT RAISE(FAIL, "Credit involved in transactions to revoke at first");
END;

