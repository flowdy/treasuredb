#!/usr/bin/perl

=head1 NAME

pseudonymizr.pl - Unambiguous substitution of marked strings by randomized ones

=head1 USE CASE

Societies that consider to use treasuredb for their finances are
strongly advised to test it in advance. The board members may do that
themselves, but they might want to delegate that to competent regular
members. However, in the latter case, privacy laws are to be observed that
can prohibit disclosure of real data for this purpose.

To conduct tests with real data without infringement of privacy laws,
this script has been developped. It replaces all names and other sensible
information that is specially marked, by a random string. It is guaranteed
that repeatedly occurring strings are replaced by the same pseudonym,
of course.

=head1 HOW IT WORKS

This script pseudonymizes lines from standard input and writes them to
standard output. All strings that need to be replaced must be wrapped into
a special marker, namely X{...}, where X can be any upper- or lowercase letter of the alphabet, denoting a certain category of information, e.g. "M" for
member names.

Caution with natural member names! Slightly differing content of M{...} clauses lead to completely different pseudonyms. In order not to render the tests
irreversible and in disaccord with actual states, because the association of members and accounts is wrong, you should prefer using it for the unique and standard member ID, say the number in the member table. Where proper names in financial transfer information, use a different letter. 

=head1 COMMAND

 pseudonymizr.pl [-r] secret_registry.txt < in_file.csv > out_file.csv

=head1 FLAGS

=over 4

=item -r

reverse mode, i.e. de-pseudonymize

=back

=cut

use strict;
use utf8;

my $LENGTH = 5;
my @CHARS = ( 'A' .. 'Z', 'a' .. 'z', 0 .. 9 );

my (%subst, %known, $registry_fh);
my $reverse_mode = $ARGV[0] eq q{-r} && shift;
my $registry_file = shift;
open $registry_fh, '<:utf8', $registry_file
    or die "Cannot read $registry_file: $!"
    if -e $registry_file;

if ( $registry_fh ) {
    
    my ($orig, $random);
    my ($h1, $h2, $assign) = $reverse_mode
        ? (\%subst => \%known, sub { ($random, $orig) = @_ })
        : (\%known => \%subst, sub { ($orig, $random) = @_ })
        ;

    while ( $_ = <$registry_fh> ) {
        chomp;
        $assign->( split /\t/ );
        $h1->{ $random } = $orig;
    }
    %$h2 = reverse %$h1;

}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
while ( $_ = <STDIN> ) {
    s/ (?<=\w\{) (.+?) (?=\}) / pseudonymize($1) /gexms;
    print;
}

unless ( $reverse_mode ) {
   # Rewrite the registry we could have expanded with new names (sorted)

   open $registry_fh, '|-', qq{sort > $registry_file}
       or die "Cannot pipe to sort: $!";

   while ( my ($random, $orig) = each %known ) {
       printf $registry_fh "%s\t%s\n", $random, $orig;
   }

}

sub pseudonymize { my $orig = shift; $subst{ $orig } //= do {{

    # Zufallsstring der Länge $LENGTH erzeugen
    my $random = join q{}, map { $CHARS[ rand 62 ] } 1 .. $LENGTH;

    # If known, try anew (p = 1 : 62 ^ $LENGTH, i.e. p > 0)
    $_ = $_ ? redo : $orig for $known{ $random };

    # in $subst speichern
    $random;

}}; }       
