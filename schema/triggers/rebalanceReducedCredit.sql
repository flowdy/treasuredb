-- When a transfer is revoked, the targetCredit of the associated bill is reduced. Hence we must
-- check if we can still have paid the debts linked to this transfer in an "is paid from" relation,
-- otherwise we have to revoke these transfers as well.
CREATE TRIGGER rebalanceReducedCredit
    AFTER UPDATE OF value ON Credit
WHEN NEW.value < OLD.spent
BEGIN

    REPLACE INTO __DO_NOT_MANIPULATE__trigger_memory (d, m)
    SELECT
        'from_' || NEW.credId,
        billId 
    FROM Transfer
    WHERE credId = NEW.credId
    ORDER BY timestamp DESC
    LIMIT 1
    ;

    DELETE
    FROM Transfer
    WHERE credId = NEW.credId
      AND billId IN (
        SELECT billId
        FROM __DO_NOT_MANIPULATE__trigger_memory
        WHERE c = 'from_' || NEW.credId
      )
    ;

    INSERT INTO Transfer (credId, billId)
        SELECT NEW.credId, m
        FROM __DO_NOT_MANIPULATE__trigger_memory
        WHERE d = 'from_' || NEW.credId
          AND NEW.value > (
              SELECT spent
              FROM Credit
              WHERE credId = NEW.credId
          )
    ;

    DELETE FROM __DO_NOT_MANIPULATE__trigger_memory WHERE d = 'from_' || NEW.credId;

END;

