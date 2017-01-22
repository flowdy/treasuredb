CREATE TRIGGER revokeTransfer
    BEFORE DELETE ON Transfer
    WHEN OLD.amount > 0
BEGIN

  INSERT INTO __INTERNAL_TRIGGER_STACK VALUES (
      OLD.ROWID, OLD.billId, OLD.credId, -OLD.amount
  );

END;

