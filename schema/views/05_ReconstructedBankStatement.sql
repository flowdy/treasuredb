DROP VIEW IF EXISTS ReconstructedBankStatement;
CREATE VIEW ReconstructedBankStatement AS
  SELECT c.date    AS date,
         c.purpose AS purpose,
         account,
         c.value   AS credit,
         NULL      AS debit
  FROM Credit AS c
    LEFT OUTER JOIN Debit AS d ON c.credId = d.targetCredit
  GROUP BY c.credId
    HAVING count(d.billId) == 0 -- exclude internal transfers
  UNION
  SELECT date,
         purpose,
         debtor     AS account,
         NULL       AS credit,
         value      AS debit
  FROM Debit
  WHERE targetCredit IS NULL    -- exclude internal transfers
  ORDER BY date ASC
;
