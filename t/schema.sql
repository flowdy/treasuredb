PRAGMA foreign_keys = ON;
PRAGMA recursive_triggers = ON;

-- To understand the sql below, see the schema.sql file.

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

.separator "	"
SELECT "ID:	credit	promise debt";
SELECT "--------------------------------";

SELECT ID || ":", credit, '+' || promised, arrears * -1 FROM Balance WHERE ID in ("john", "Club");

SELECT "# Reflect john paying its bills all at once ...";
INSERT INTO Transfer (billId, credId) VALUES ("MB1605-john", 2), ("MB1606-john", 2), ("MB1607-john", 2), ("MB1608-john", 2), ("MB1609-john", 2), ("MB1610-john", 2), ("MB1611-john", 2), ("MB1612-john", 2), ("MB1701-john", 2), ("MB1702-john", 2), ("MB1703-john", 2), ("MB1704-john", 2); 
SELECT ID || ":", credit, '+' || promised, arrears * -1 FROM Balance WHERE ID in ("john", "Club");

SELECT "# Charge Club with server hosting provided by alex ...";
INSERT INTO Transfer (billId, credId) VALUES ("TWX2016/123", 1);
SELECT ID || ":", credit, '+' || promised, arrears * -1 FROM Balance WHERE ID in ("Club", "alex");

SELECT "# Some updates and deletes that could, unless denied, destroy consistency ...";
UPDATE Debit SET paid = 20000 WHERE billId="TWX2016/123";
UPDATE Debit SET value = 20000 WHERE billId="TWX2016/123";
DELETE FROM Debit WHERE billId="TWX2016/123"; -- *SHOULD NOT* work

SELECT "# After revoking transactions, you are free to change or delete debts and credits ...";
BEGIN TRANSACTION;
DELETE FROM Transfer WHERE billId="TWX2016/123";
UPDATE Debit SET value = 20000 WHERE billId="TWX2016/123";
DELETE FROM Debit WHERE billId="TWX2016/123"; -- *SHOULD* work
SELECT ID || ":", credit, '+' || promised, arrears * -1 FROM Balance WHERE ID in ("Club", "alex");
ROLLBACK TRANSACTION;

SELECT '# But let''s rollback that what-if excurse. This is how it currently is ...';
SELECT ID || ":", credit, '+' || promised, arrears * -1 FROM Balance WHERE ID in ("Club", "alex");

SELECT '###################################################################';
SELECT '# Now it is your turn: Study the sql code yielding the output above';
SELECT '# then enter new members and let them pay the fees.';
SELECT '# (PLUS: Let have one discalculia and pay too little or too much.)';
SELECT '# Once the club has enough money to pay alex'' hosting service,';
SELECT '# update (i.e. revoke and reenter) the respective transaction.';
SELECT '# Finally issue a bank transfer to alex. Hint: An outgoing transfer';
SELECT '# is simply a debt charging alex'' own virtual account and without';
SELECT '# targetCredit (NULL). PLUS: What happens if the description of';
SELECT '# the bank transfer does not contain any or only a wrong IBAN?';
