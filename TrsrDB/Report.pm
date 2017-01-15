use strict;

package TrsrDB::Report;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Report');
__PACKAGE__->add_column("account");
__PACKAGE__->add_column("credId" => { data_type => 'INTEGER' });
__PACKAGE__->add_column("date" => { data_type => 'DATE' });
__PACKAGE__->add_column("purpose");
__PACKAGE__->add_column("value" => { data_type => 'INTEGER' });

__PACKAGE__->belongs_to(
    account => 'TrsrDB::Account',
    { 'foreign.ID' => 'self.account' }
);

1;
