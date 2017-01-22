CREATE TRIGGER enforceImmutableTransfer
    BEFORE UPDATE ON Transfer
    WHEN OLD.amount IS NOT NULL
      AND NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK)
BEGIN
    SELECT RAISE(FAIL, "Transfer cannot be updated, but needs to be replaced to make triggers run");
END;

