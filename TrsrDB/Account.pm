use strict;

package TrsrDB::Account;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Account');
__PACKAGE__->add_columns(qw/ID name type altId IBAN/);
__PACKAGE__->set_primary_key('ID');

__PACKAGE__->has_many(
    statement_rows => 'TrsrDB::ReconstructedBankStatement',
    { 'foreign.account' => 'self.ID' }
);
__PACKAGE__->has_many(
    debits => 'TrsrDB::Debit',
    { 'foreign.debtor' => 'self.ID' }
);
__PACKAGE__->has_many(
    current_arrears => 'TrsrDB::CurrentArrears',
    { 'foreign.debtor' => 'self.ID' }
);
__PACKAGE__->has_many(
    credits => 'TrsrDB::Credit',
    { 'foreign.account' => 'self.ID' }
);
__PACKAGE__->has_many(
    available_credits => 'TrsrDB::AvailableCredits',
    { 'foreign.account' => 'self.ID' }
);
__PACKAGE__->has_one(
    balance => 'TrsrDB::Balance', 'ID'
);
__PACKAGE__->has_many(
    history => 'TrsrDB::History',
    { 'foreign.account' => 'self.ID' }
);
__PACKAGE__->has_many(
    report => 'TrsrDB::Report',
    { 'foreign.account' => 'self.ID' }
);

1;
