CREATE TRIGGER enforceImmutableTransfer
    BEFORE UPDATE ON Transfer
    WHEN OLD.amount IS NOT NULL
BEGIN
    SELECT RAISE(FAIL, "Transfer cannot be updated, but needs to be replaced to make triggers run");
END;

