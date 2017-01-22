-- Prevent modification of paid value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceDebtImmutableOutsideTrigger
    BEFORE UPDATE OF paid ON Debit
    WHEN NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK LIMIT 1)
BEGIN
    SELECT RAISE(FAIL, "paid is set and adjusted automatically according to added Transfer records");
END;

