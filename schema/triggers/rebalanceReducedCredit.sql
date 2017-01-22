-- When a transfer is revoked, the targetCredit of the associated bill is reduced. Hence we must
-- check if we can still have paid the debts linked to this transfer in an "is paid from" relation,
-- otherwise we have to revoke these transfers as well.
CREATE TRIGGER rebalanceReducedCredit
    BEFORE UPDATE OF value ON Credit
    WHEN NEW.value < OLD.spent
BEGIN
    INSERT INTO __INTERNAL_TRIGGER_STACK (id) VALUES (-NEW.credId);
    UPDATE __INTERNAL_TRIGGER_STACK SET c=OLD.spent-NEW.value;
    DELETE FROM __INTERNAL_TRIGGER_STACK WHERE id=-NEW.credId;
END;

CREATE TRIGGER _inner_rebalanceReducedCredit
    AFTER UPDATE OF c ON __INTERNAL_TRIGGER_STACK
BEGIN

    UPDATE __INTERNAL_TRIGGER_STACK
        SET d = (
            SELECT ROWID
            FROM Transfer
            WHERE credId = abs(OLD.id)
            ORDER BY timestamp DESC
            LIMIT 1
          )
        WHERE id = OLD.id
    ;

    UPDATE __INTERNAL_TRIGGER_STACK
        SET m = min((
            SELECT amount
            FROM Transfer
            WHERE credId = abs(OLD.id)
            ORDER BY timestamp DESC
            LIMIT 1
          ), NEW.c)
        WHERE id = OLD.id
    ;

    INSERT INTO __INTERNAL_TRIGGER_STACK
        SELECT d, billId, abs(OLD.id), -m
          FROM __INTERNAL_TRIGGER_STACK s
              JOIN Transfer t ON t.ROWID=d
          WHERE id = OLD.id AND m > 0
    ;

    UPDATE __INTERNAL_TRIGGER_STACK
        SET c = NEW.c-m
        WHERE id = OLD.id AND m > 0
    ; -- recurse

END;
