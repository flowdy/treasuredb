use strict;

package TrsrDB::History;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('History');
__PACKAGE__->add_columns(qw/date purpose account credit debit contra billId/);

__PACKAGE__->belongs_to(
   account => 'TrsrDB::Account',
   { 'foreign.ID' => 'self.account' }
);

1;
