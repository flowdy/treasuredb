use strict;

package TrsrDB::Category;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('category');
__PACKAGE__->add_columns(qw/ID label/);
__PACKAGE__->set_primary_key('ID');

__PACKAGE__->has_many(
    debits => 'TrsrDB::Debit',
    { 'foreign.category' => 'self.ID' }
);
__PACKAGE__->has_many(
    credits => 'TrsrDB::Credit',
    { 'foreign.category' => 'self.ID' }
);

1;
