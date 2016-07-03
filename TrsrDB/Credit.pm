use strict;

package TrsrDB::Credit;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Credit');
__PACKAGE__->add_column("credId" => { data_type => 'INTEGER' });
__PACKAGE__->add_column("account");
__PACKAGE__->add_column("date" => { data_type => 'DATE' });
__PACKAGE__->add_column("purpose");
__PACKAGE__->add_column("value" => { data_type => 'INTEGER' });
__PACKAGE__->add_column("spent" => { data_type => 'INTEGER', default => 0 });
__PACKAGE__->set_primary_key("credId");

__PACKAGE__->belongs_to(
    account => 'TrsrDB::Account',
    { 'foreign.ID' => 'self.account' }
);

__PACKAGE__->has_many(
    outgoings => 'TrsrDB::Transfer',
    { 'foreign.fromCredit' => 'self.Id' }
);

__PACKAGE__->many_to_many(
    paid_bills => 'outgoings' => 'debit'
);

1;
