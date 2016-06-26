use strict;

package TrsrDB;
use base qw/DBIx::Class::Schema/;
use Carp qw/croak/;

__PACKAGE__->load_classes(qw|
    Account Debit Credit Transfer CurrentDebts AvailableCredits
    Balance ReconstructedBankStatement History
|);

sub import {
    my ($class, $dbh_ref, $filename) = @_;
    return if @_ == 1;
    croak "use TrsrDB \$your_db_handle missing" if !defined $dbh_ref;
    $$dbh_ref = $class->connect(
        "DBI:SQLite:" . ($filename // ":memory:"),
        "", "", {
           sqlite_unicode => 1,
           on_connect_call => 'use_foreign_keys',
           on_connect_do => 'PRAGMA recursive_triggers = 1',
        }
    );
}

1;
