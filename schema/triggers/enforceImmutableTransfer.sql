CREATE TRIGGER enforceImmutableTransfer
    BEFORE UPDATE OF timestamp, credId, billId, amount ON Transfer -- Allow update of note
    WHEN OLD.amount IS NOT NULL
      AND NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK)
BEGIN
    SELECT RAISE(FAIL, "Transfer cannot be updated, but needs to be replaced to make triggers run");
END;

