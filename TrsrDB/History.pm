use strict;

package TrsrDB::History;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('History');
__PACKAGE__->add_columns(qw/date purpose account credId credit debit contra billId note/);

__PACKAGE__->belongs_to(
   account => 'TrsrDB::Account',
   { 'foreign.ID' => 'self.account' }
);

__PACKAGE__->belongs_to(
   this_credit => 'TrsrDB::Credit',
   { 'foreign.credId' => 'self.credId' }
);

__PACKAGE__->belongs_to(
   that_credit => 'TrsrDB::Credit',
   { 'foreign.credId' => 'self.contra' }
);

1;
