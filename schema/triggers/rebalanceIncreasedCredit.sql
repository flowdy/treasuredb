-- When we enter a transfer, the targetCredit of the associated bill might already be the credId
-- of a transfer for other dues itself. We can update (replace) the transfer for an unfullfilled one.
-- That way, a transfer may issue recursively chained transfers.
CREATE TRIGGER rebalanceIncreasedCredit
    AFTER UPDATE OF value ON Credit
    WHEN NEW.value > OLD.value
BEGIN

    INSERT INTO __INTERNAL_TRIGGER_STACK
        SELECT t.ROWID, t.billId, t.credId,
            min(ca.difference, NEW.value - OLD.value)
        FROM Transfer t
          JOIN CurrentArrears ca ON t.billId = ca.billId
        WHERE OLD.credId = t.credId
    ;

END;
