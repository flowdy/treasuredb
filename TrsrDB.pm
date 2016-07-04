use strict;

package TrsrDB;
use base qw/DBIx::Class::Schema/;
use Carp qw/croak/;

__PACKAGE__->load_classes(qw|
    Account Debit Credit Transfer CurrentArrears AvailableCredits
    Balance ReconstructedBankStatement History
|);

sub import {
    my ($class, $dbh_ref, $filename) = @_;
    return if @_ == 1;
    croak "use TrsrDB \$your_db_handle missing" if !defined $dbh_ref;
    $$dbh_ref = $class->connect(
        "DBI:SQLite:" . ($filename // $ENV{TRSRDB_SQLITE_FILE} // ":memory:"),
        "", "", {
           sqlite_unicode => 1,
           on_connect_call => 'use_foreign_keys',
           on_connect_do => 'PRAGMA recursive_triggers = 1',
        }
    );
}

sub autobalance {
    my ($self, @pairs) = @_;

    my $from_to = [
        undef, AvailableCredits => 'credId',
        suggested_to_pay => 'billId', undef
    ];
    my $to_from = [
        undef, CurrentArrears => 'billId',
        payable_with => 'Id', undef
    ];

    my $transfers = $self->resultset('Transfer');
    my @dir = ($from_to, $to_from);
    my ($rs, $transferred_total, $src_total, $tgt_total);
    
    while ( my ($src, $tgt) = splice @pairs, 0, 2 ) {

        $rs = $self->resultset("AvailableCredits")->search({
            credId => [ -or => _expand_ids($src) ]
        });
        $src = [ $rs->get_column('credId')->all ];
        $src_total += $rs->get_column('difference')->sum;

        $rs = $self->resultset("CurrentArrears")->search({
            billId => [ -or => _expand_ids( $tgt ) ]
        });
        $tgt = [ $rs->get_column('billId')->all ];
        $tgt_total += $rs->get_column('difference')->sum;

        @{$to_from}[5,0] = @{$from_to}[0,5] = ($src, $tgt); 
        my $i = 0;
        while ( @$src && @$tgt ) {

            my ($item, $thistable, $thisidname,
                $m2mrel, $otheridname, $otherids)
                = @{ $dir[ $i ] }
                ;

            1 until $item
                = $self->resultset($thistable)->find(
                    shift(@$item) // last
                  );

            my $diff = $item->difference;
            my @otherids =
                $item->$m2mrel({
                    $otheridname => { -in => $otherids }
                })->get_column($otheridname)->all
            ;
            my $transfer;
            while ( $diff > 0 ) {
                $transfer = $transfers->create({
                    $thisidname => $item->id,
                    $otheridname => shift(@otherids) // last
                });
                $transfer->discard_changes; # sorry, DBIx::Class devs, what a bad name!
                                            # how about 'refresh_from_storage'
                for ( $transfer->amount ) {
                     $diff -= $_;
                     $transferred_total += $_;
                }
            }
            redo if !$diff;

        }
        continue {
            $i = !$i || 0;
        }

    }

    return $src_total, $tgt_total, $transferred_total // 0;

}

sub _expand_ids {
    my ($ids) = @_;
    my @ids = map { m{ \A (\d+) - (\d+) \z }xms ? [ $1 .. $2 ] : $_ }
              ref $ids ? @$ids : split q{,}, $ids
            ;
    my (@alternatives, @raws);
    for my $id ( @ids ) {
        if ( ref $id eq 'ARRAY' ) {
            push @raws, @$ids;
        }
        elsif ( $id eq '*' ) {
           @alternatives = ({ -not_in => [] });
        }
        elsif (
            $id =~ s{([%*_?])}{
                $1 eq '*' ? '%' : $1 eq '?' ? '_' : $1
            }eg
        ) {
           push @alternatives, { -like => $id };
        }
        else {
           push @raws, $id;
        }
    }
    push @alternatives, @raws ? { -in => \@raws } : ();
    return \@alternatives;
}
1;
