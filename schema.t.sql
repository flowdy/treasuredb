PRAGMA foreign_keys = ON;

INSERT INTO Account VALUES ("Club", "eV", 1, NULL), ("john", "Member", 44, NULL), ("alex", "Member", 6, "DE1234567890123456");

INSERT INTO Credit VALUES (1, "Club", "2016-01-01", "Membership fees May 2016 until incl. April 2017", 0, 0),
                         (2, "john", "2016-04-23", "Membership fee 2016f.", 7200, 0),
                         (3, "alex", "2016-01-15", "Payment for Server Hosting 2016", 0, 0);

INSERT INTO Debit VALUES ("MB1605-john", "john", 1, "2016-05-01", "Membership fee May 2016", 600, 0),
                        ("MB1606-john", "john", 1, "2016-05-01", "Membership fee June 2016", 600, 0),
                        ("MB1607-john", "john", 1, "2016-05-01", "Membership fee July 2016", 600, 0),
                        ("MB1608-john", "john", 1, "2016-05-01", "Membership fee August 2016", 600, 0),
                        ("MB1609-john", "john", 1, "2016-05-01", "Membership fee September 2016", 600, 0),
                        ("MB1610-john", "john", 1, "2016-05-01", "Membership fee October 2016", 600, 0),
                        ("MB1611-john", "john", 1, "2016-05-01", "Membership fee November 2016", 600, 0),
                        ("MB1612-john", "john", 1, "2016-05-01", "Membership fee December 2016", 600, 0),
                        ("MB1701-john", "john", 1, "2016-05-01", "Membership fee January 2017", 600, 0),
                        ("MB1702-john", "john", 1, "2016-05-01", "Membership fee February 2017", 600, 0),
                        ("MB1703-john", "john", 1, "2016-05-01", "Membership fee March 2017", 600, 0),
                        ("MB1704-john", "john", 1, "2016-05-01", "Membership fee April 2017", 600, 0),
                        ("TWX2016/123", "Club", 3, "2016-01-15", "Server Hosting 2016", 23450, 0);

.separator " "
SELECT "Balance of " || ID || "'s account:", credit, debit * -1 FROM Balance WHERE ID in ("john", "Club");
INSERT INTO Transfer (receiptId, fromCredit) VALUES ("MB1605-john", 2), ("MB1606-john", 2), ("MB1607-john", 2), ("MB1608-john", 2), ("MB1609-john", 2), ("MB1610-john", 2), ("MB1611-john", 2), ("MB1612-john", 2), ("MB1701-john", 2), ("MB1702-john", 2), ("MB1703-john", 2), ("MB1704-john", 2); 
SELECT "Balance of " || ID || "'s account:", credit, debit * -1 FROM Balance WHERE ID in ("john", "Club");
INSERT INTO Transfer (receiptId, fromCredit) VALUES ("TWX2016/123", 1);
SELECT "Balance of " || ID || "'s Account:", credit, debit * -1 FROM Balance WHERE ID in ("Club", "alex");
UPDATE Debit SET paid = 20000 WHERE receiptId="TWX2016/123";
UPDATE Debit SET value = 20000 WHERE receiptId="TWX2016/123";
DELETE FROM Debit WHERE receiptId="TWX2016/123"; -- *SHOULD NOT* work
BEGIN TRANSACTION;
DELETE FROM Transfer WHERE receiptId="TWX2016/123";
UPDATE Debit SET value = 20000 WHERE receiptId="TWX2016/123";
DELETE FROM Debit WHERE receiptId="TWX2016/123"; -- *SHOULD* work
SELECT "Balance of " || ID || "'s Account:", credit, debit * -1 FROM Balance WHERE ID in ("Club", "alex");
ROLLBACK TRANSACTION;
SELECT "Balance of " || ID || "'s Account:", credit, debit * -1 FROM Balance WHERE ID in ("Club", "alex");
