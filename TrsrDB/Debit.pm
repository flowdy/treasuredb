use strict;

package TrsrDB::Debit;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('Debit');
__PACKAGE__->add_column("billId");
__PACKAGE__->add_column("debtor");
__PACKAGE__->add_column("date" => { data_type => 'DATE' });
__PACKAGE__->add_column("purpose");
__PACKAGE__->add_column("category", { is_nullable => 1 });
__PACKAGE__->add_column("value" => { data_type => 'INTEGER' });
__PACKAGE__->add_column("paid" => { data_type => 'INTEGER', default => 0 });
__PACKAGE__->set_primary_key("billId");
__PACKAGE__->add_column("targetCredit" => {
    data_type => 'INTEGER',
    is_nullable => 1
});

__PACKAGE__->belongs_to(
    account => 'TrsrDB::Account',
    { 'foreign.ID' => 'self.debtor' }
);

__PACKAGE__->belongs_to(
    target => 'TrsrDB::Credit',
    { 'foreign.credId' => 'self.targetCredit' }
);

__PACKAGE__->belongs_to(
    category_row => 'TrsrDB::Category',
    { 'foreign.ID' => 'self.category' }
);

__PACKAGE__->has_many(
    incomings => 'TrsrDB::Transfer', 'billId'
);

__PACKAGE__->many_to_many(
    paid_with => incomings => 'credit'
);

1;
