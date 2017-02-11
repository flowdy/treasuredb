use strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new("TrsrDB::HTTP");

my ($url) = qx{perl httpuser -a test -g 2} =~ m{^\s*<FQDN>(.*?)\s}xms;

ok length($url), "User created";

$t->get_ok($url);

$t->content_like(qr/name="samepassword"/, "Page asks for password repetition");

$t->post_ok($url => form => { user => "test", password => "pw", samepassword => "pw" })
  ->status_is(302)->header_is( Location => "/" );

$t->get_ok("/logout");

$t->get_ok("/")->status_is(302)->header_is( Location => "/login" );

$t->post_ok("/login" => form => { user => "test", password => "pw" })
  ->status_is(302)->header_is( Location => "/" );

$t->post_ok("/account" => form => $_ )->header_is( Location => "/" )
    for { ID => "Club", type => q{}, altId => 1, IBAN => "*", name => "Main account" }, 
        { ID => "john", name => "John Tester", type => "Member", altId => 44 },
        { ID => "alex", name => "Alex Webber", type => "Member", altId => 6, IBAN => "DE12345678901234567890" },
        { ID => "rose", name => "Delia Rosenthal", altId => 45, type => 'Member' },
        { ID => "flow", name => "Florian Hess", altId => 67, type => 'Member' },
    ; 

done_testing();
