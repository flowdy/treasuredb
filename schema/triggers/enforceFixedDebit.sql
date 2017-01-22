CREATE TRIGGER enforceFixedDebit
    BEFORE UPDATE OF debtor, transferCredit, value ON Debit
    WHEN EXISTS (SELECT * FROM Transfer WHERE billId=NEW.billId)
     AND NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK LIMIT 1)
BEGIN
    SELECT RAISE(FAIL, "Debt is involved in transfers to revoke at first");
END;

