use strict;

package TrsrDB::AvailableCredits;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('AvailableCredits');
__PACKAGE__->add_columns(qw/ Id account date purpose difference /);
__PACKAGE__->set_primary_key("Id");

__PACKAGE__->belongs_to(
    account => 'TrsrDB::Account',
    { 'foreign.ID' => 'self.account' }
);

__PACKAGE__->many_to_many(
    suggested_to_pay => account => 'current_debts'
);

1;
