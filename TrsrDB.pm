use strict;

package TrsrDB;
use base qw/DBIx::Class::Schema/;
use Carp qw/croak/;

__PACKAGE__->load_classes(qw|
    Account Debit Credit Transfer CurrentArrears AvailableCredits
    Category Balance Report ReconstructedBankStatement History User
|);

sub import {
    my ($class, $dbh_ref, $filename) = @_;
    return if @_ == 1;
    croak "use TrsrDB \$your_db_handle missing" if !defined $dbh_ref;
    my $filename //= $ENV{TRSRDB_SQLITE_FILE}
        // croak "No database to open: TRSRDB_SQLITE_FILE environment variable not set, "
               . "and no filename passed to ".__PACKAGE__."::import() / use";
    if ( !(-f $filename && -r $filename) ) {
        croak "Cannot read database file $filename";
    }

    $$dbh_ref = $class->connect(
        "DBI:SQLite:" . ($filename // $ENV{TRSRDB_SQLITE_FILE}
            // die "No database to open: TRSRDB_SQLITE_FILE environment variable not set\n"),
        "", "", {
           sqlite_unicode => 1,
           on_connect_call => 'use_foreign_keys',
           on_connect_do => 'PRAGMA recursive_triggers = 1',
        }
    );
}

sub make_transfers {
    my ($self, @pairs) = @_;

    my $from_to = [
        undef, AvailableCredits => 'credId',
        suggested_to_pay => 'billId', undef
    ];
    my $to_from = [
        undef, CurrentArrears => 'billId',
        payable_with => 'credId', undef
    ];

    my $transfers = $self->resultset('Transfer');
    my @dir = ($from_to, $to_from);
    my ($rs, $transferred_total, $src_total, $tgt_total);
    
    while ( my ($src, $tgt) = splice @pairs, 0, 2 ) {

        $rs = $self->resultset("AvailableCredits")->search(
            expand_ids($src => 'credId' )
        );
        $src = [ $rs->get_column('credId')->all ];
        $src_total += $rs->get_column('difference')->sum;

        $rs = $self->resultset("CurrentArrears")->search(
            expand_ids( $tgt => 'billId' )
        );
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

sub expand_ids {
    my ($ids, $default_slot) = @_;
    my @ids = map { m{ \A (\d+) - (\d+) \z }xms ? [ $1 .. $2 ] : $_ }
              ref $ids ? @$ids : split q{,}, $ids
            ;
    my (@alternatives, %raws);
    for my $id ( @ids ) {

        my $slot = ref $id ? $default_slot
                 : $id =~ s{^p(urpose)?:}{}i ? "purpose"
                 : $id =~ s{^d(ate)?:}{}i ? "date"
                 : $id =~ s{^v(alue)?:}{}i ? "value"
                 : $default_slot
                 ;

        if ( ref $id eq 'ARRAY' ) {
            $raws{$slot}{'-in'}, @$ids;
        }
        elsif ( $id eq '*' ) {
           @alternatives = ( $slot => { -not_in => [] });
        }
        elsif (
            $id =~ s{([%*_?])}{
                $1 eq '*' ? '%' : $1 eq '?' ? '_' : $1
            }eg
        ) {
           push @alternatives, { $slot => { -like => $id } };
        }
        else { push @{ $raws{$slot}{'-like'} }, $id }
    }
    while ( my @v = each %raws ) { push @alternatives, { @v } }
    return \@alternatives;
}

sub user {
    shift->resultset("User")->find(shift);
}

1;
