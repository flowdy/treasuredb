use strict;

package TrsrDB::Transfer;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Transfer');
__PACKAGE__->add_column("timestamp" => { data_type => 'TIMESTAMP' });
__PACKAGE__->add_column("billId");
__PACKAGE__->add_column("credId" => { data_type => 'INTEGER' });
__PACKAGE__->add_column("amount" => { data_type => 'INTEGER', nullable => 1 });
__PACKAGE__->set_primary_key("billId", "credId");

__PACKAGE__->belongs_to(
   credit => 'TrsrDB::Credit', 'credId'
);

__PACKAGE__->belongs_to(
   debit => 'TrsrDB::Credit', 'billId'
);

1;
