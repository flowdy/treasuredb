use strict;

my $db;
use TrsrDB \$db => 'trsr.db';
use Test::More;

$db->resultset("Account")->create({ ID => "Club", altId => 1, type => 'eV' }); 
$db->resultset("Account")->create({ ID => "john", altId => 44, type => 'Member' }); 
$db->resultset("Account")->create({
    ID => "alex", altId => 6, type => 'Member',
    IBAN => 'DE1234567890123456' # used for verification in outgoing bank transfers
}); 

is_deeply
    [ $db->resultset("Account")->search(
        {}, { -order_by => { asc => ['ID'] } }
      )->get_column('ID')->all
    ],
    [ qw/ Club alex john / ],
    "Registering new accounts"
;

$db->resultset("Credit")->create($_) for
    { account => "Club", date => "2016-01-01",
      purpose => "Membership fees May 2016 until incl. April 2017",
      value => 0
    },
    { account => "john", date => "2016-04-23",
      purpose => "Membership fee 2016f.",
      value => 7200
    },
    { account => "alex", date => "2016-01-15",
      purpose => "Payment for Server Hosting 2016",
      value => 0,
    }
;

is_deeply [ map { $db->resultset("Account")->find($_)->credits->count() } qw(Club john alex) ],
          [ 1, 1, 1 ], "Entering one credit per account";

my %months = (
    '05' => 'May 2016',       '06' => 'June 2016',     '07' => 'July 2016',     '08' => 'August 2016',
    '09' => 'September 2016', '10' => 'October 2016',  '11' => 'November 2016', '12' => 'December 2016',
    '01' => 'January 2017',   '02' => 'February 2017', '03' => 'March 2017',    '04' => 'April 2017',
);
while ( my ($num, $month) = each %months ) {
    my $yy = substr $month, -2;
    $db->resultset("Debit")->create({
        billId => "MB$yy$num-john",
        debtor => "john",
        targetCredit => 1,
        date => "16-05-01",
        purpose => "Membership fee $month",
        value => 600
    });
}

is $db->resultset("Account")->find("john")->current_arrears->count(), 12,
   "Entering outstanding member fees for john";

$db->resultset("Account")->find("Club")->add_to_debits({
    billId => "TWX2016/123",
    targetCredit => 3,
    date => "2016-01-15",
    purpose => "Server Hosting 2016",
    value => 23450
});

is $db->resultset("Debit")->search({ debtor => 'Club' })->single->billId, "TWX2016/123", "Invoicing server hosting for club";

is_deeply {
    map { $_->ID => {$_->get_columns} }
    $db->resultset("Balance")->all
}, {
    john => { ID => 'john', credit => 7200, arrears => 7200,  promised => 0 },
    Club => { ID => 'Club', credit => 0, arrears => 23450, promised => 7200 },
    alex => { ID => 'alex', credit => 0, arrears => 0, promised => 23450 },
},
"Get balances"
;    

# Transfer 72 Euro (6 Euro per month) from john's to Club account.
# Transfer same 72 Euro from Club account to alex hosting the web site.
is $db->autobalance( (q{*} => q{*}) x 2 ), 14400, 'Automatically balanced credits and debits';

done_testing();
