use strict;

package TrsrDB::Balance;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table("Balance");
__PACKAGE__->add_columns(qw/ID credit promised debt/);
__PACKAGE__->set_primary_key("ID");

__PACKAGE__->belongs_to(
   account => 'TrsrDB::Account', 'ID'
);
 
1;
