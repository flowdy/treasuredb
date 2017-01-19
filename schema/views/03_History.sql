-- Log of internal transfers
DROP VIEW IF EXISTS History;
CREATE VIEW History AS
  -- internal transfers with account as source
  SELECT DATE(timestamp) AS date,
         d.purpose       AS purpose,
         d.debtor        AS account,
         t.credId        AS credId,
         t.amount        AS debit,
         NULL            AS credit,
         d.targetCredit  AS contra,
         d.billId        AS billId,
         t.note          AS note
  FROM Transfer t
    LEFT JOIN Debit  AS d ON d.billId = t.billId
  -- internal transfers with account as target
  UNION
  SELECT DATE(timestamp) AS date,
         d.purpose       AS purpose,
         c.account       AS account,
         d.targetCredit  AS credId,
         NULL            AS debit,
         t.amount        AS credit,
         t.credId        AS contra,
         d.billId        AS billId,
         t.note          AS note
  FROM Transfer t
    LEFT JOIN Debit  AS d ON d.billId = t.billId
    LEFT JOIN Credit AS c ON c.credId = d.targetCredit
  ORDER BY date ASC
;
