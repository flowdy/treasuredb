use strict;

package TrsrDB::HTTP::Debit;
use Mojo::Base 'Mojolicious::Controller';
use Carp qw(croak);
use POSIX qw(strftime);

sub list {
    my $self = shift;

    my $accounts = $self->app->db->resultset("Account");

    my %args = $self->stash("user")->grade ? () : ( type => undef );
    $args{ID} = $self->stash("account");
    my $account = $accounts->find(\%args);

    if ( !$account ) {
        $self->reply->not_found;
        return;
    }

    my $rs = $account->search_related(
        debits => TrsrDB::HTTP::process_table_filter_widget(
            $self, {}, { order_by => { -desc => [qw/date/] }}
        )
    );
    $self->stash( debits => $rs );

    return;

}

sub upsert {
    my $self = shift;
    
    my $db = $self->app->db;
    my $id = $self->stash("id");
    my @FIELDS = qw/billId date purpose category value targetCredit/;
    my $debtor = $self->stash("account") // $self->param("debtor");
    if ( $self->req->method eq 'POST' && $debtor =~ s{^@}{} ) {

        my $group_members = $db->resultset('Account')->search({
            type => $debtor
        });

        while ( my $m = $group_members->next ) {
            my %props = map { $_ => $self->param($_) } @FIELDS;
            $props{targetCredit} ||= undef;
            for ( $props{billId} ) {
                 s{\%u}{ $m->ID }e or $_ .= "-" . $m->ID;
            }
            $m->debits->create( \%props );
        }
        
        $self->redirect_to('home');
        return;
    }

    my $method = $id ? 'find_or_new' : 'new';
    my $debit = $db->resultset("Debit")->$method({
        $id ? (billId => $id) : (),
        debtor => $debtor,
        date => strftime("%Y-%m-%d", localtime)
    });

    $self->stash( debit => $debit );

    if ( $self->req->method eq 'GET' ) {
        my $targets
          = $db->resultset("Credit")->search({ account => { '!=' => $debtor } },
                { join => 'income',
                  '+select' => [ { count => 'income.targetCredit', -as => 'targetted_by' } ],
                  group_by => ['income.targetCredit'], 
                  having   => \[ 'ifnull(sum(income.paid),0) = me.value' ],
                  order_by => { -asc => [qw/account/] },
                }
            );
        my @targets = map { [ $_->credId, $_->account->ID, $_->purpose ] } $targets->all;
        my $categories = $db->resultset("Category")->search_rs({}, {
            order_by => { -asc => [qw/ID/] }
        });
        $self->stash(
            categories => $categories,
            targets => \@targets,
            targets_count => $targets->count
        );
        return;
    }

    for my $field ( @FIELDS ) {
        my $value = $self->param($field);
        $value = undef if !length $value;
        $debit->$field($value);
    }
    $debit->update_or_insert();

    my $to_revoke = $self->every_param("revoke");
    if ( @$to_revoke ) {
        $db->resultset("Transfer")->search({
            billId => $id, credId => $to_revoke
        })->delete;
    }

    my $to_pay_with = $self->every_param("payWith");
    if ( @$to_pay_with ) {
        my $billId = $self->param("billId");
        $db->make_transfers( $to_pay_with => $billId );
    }                  

    for my $param ( grep { /^note\[/ } @{ $self->req->params->names } ) {
        my $note = $self->param($param) || next;
        s{^note\[}{} && s{\]$}{} for $param;
        $debit->search_related(
            incomings => { credId => $param }
        )->update({ note => $note });
    }    

    $self->redirect_to('home');

}

1;

