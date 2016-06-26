use strict;

package TrsrDB::ReconstructedBankStatement;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('ReconstructedBankStatement');
__PACKAGE__->add_columns(qw/date purpose account credit debit/);

1;
