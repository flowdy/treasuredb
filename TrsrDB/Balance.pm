use strict;

package TrsrDB::Balance;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table("Balance");
__PACKAGE__->add_columns(qw/ ID available earned promised spent arrears even_until /);
__PACKAGE__->set_primary_key("ID");

__PACKAGE__->belongs_to(
   account => 'TrsrDB::Account', 'ID'
);
 
1;
