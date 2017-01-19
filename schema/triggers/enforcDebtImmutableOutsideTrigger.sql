-- Prevent modification of paid value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceDebtImmutableOutsideTrigger
    BEFORE UPDATE OF paid ON Debit
    WHEN NOT EXISTS (SELECT * FROM Transfer t WHERE NEW.billId=t.billId AND amount IS NULL)
BEGIN
    SELECT RAISE(FAIL, "paid is set and adjusted automatically according to added Transfer records")
    WHERE (NEW.paid + IFNULL(
            (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory WHERE c IS NULL AND d IS NULL), 0
        ) ) <> OLD.paid;
END;

