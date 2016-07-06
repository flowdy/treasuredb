use strict;

package TrsrDB::CurrentArrears;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('CurrentArrears');
__PACKAGE__->add_columns(qw/billId debtor targetCredit date purpose difference/);
__PACKAGE__->set_primary_key("billId");

__PACKAGE__->belongs_to(
    debtor => 'TrsrDB::Account',
    { 'foreign.ID' => 'self.debtor' }
);

__PACKAGE__->many_to_many(
    payable_with => debtor => 'available_credits'
);

1;
