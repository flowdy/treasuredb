-- When we enter a transfer, the targetCredit of the associated bill might already be the credId
-- of a transfer for other dues itself. We can update (replace) the transfer for an unfullfilled one.
-- That way, a transfer may issue recursively chained transfers.
CREATE TRIGGER rebalanceIncreasedCredit
    AFTER UPDATE OF value ON Credit
WHEN NEW.value > OLD.spent
BEGIN

    REPLACE INTO Transfer (credId, billId)
        SELECT OLD.credId, t.billId
        FROM Transfer t
          JOIN CurrentArrears ca ON t.billId = ca.billId
        WHERE OLD.credId = t.credId
    ;

END;
