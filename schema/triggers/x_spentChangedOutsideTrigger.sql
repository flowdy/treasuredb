-- Prevent modification of spent value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER x_spentChangedOutsideTrigger
    BEFORE UPDATE OF spent ON Credit
    WHEN NOT EXISTS (SELECT * FROM __INTERNAL_TRIGGER_STACK)
BEGIN
    SELECT RAISE(ABORT, "spent is set and adjusted automatically according to added Transfer records");
END;

