use strict;

package TrsrDB::Account;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Account');
__PACKAGE__->add_columns(qw/ID type altId IBAN/);
__PACKAGE__->set_primary_key('ID');

__PACKAGE__->has_many(
    statement_rows => 'TrsrDB::ReconstructedBankStatement',
    { 'foreign.account' => 'self.ID' }
);
__PACKAGE__->has_many(
    debts => 'TrsrDB::Debit',
    { 'foreign.debtor' => 'self.ID' }
);
__PACKAGE__->has_many(
    current_debts => 'TrsrDB::CurrentDebts',
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

1;
