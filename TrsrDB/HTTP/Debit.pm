use strict;

package TrsrDB::HTTP::Debit;
use Mojo::Base 'Mojolicious::Controller';
use Carp qw(croak);

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

    $self->stash( debits => $account->debits_rs );

    return;

}

sub upsert {
    my $self = shift;
    
    my $db = $self->app->db;
    my $id = $self->stash("id");
    my $account = $self->stash("account");
    my $method = $id ? 'find_or_new' : 'new';
    my $debit = $db->resultset("Debit")->$method(
        { $id ? (billId => $id) : (), debtor => $account }
    );

    $self->stash( debit => $debit );

    if ( $self->req->method eq 'GET' ) {
        my $targets
          = $db->resultset("Credit")->search({ account => { '!=' => $account } },
                { join => 'income',
                  '+select' => [ { count => 'income.targetCredit', -as => 'targetted_by' } ],
                  group_by => ['income.targetCredit'], 
                  having   => \[ 'ifnull(sum(income.paid),0) = me.value' ],
                  order_by => { -asc => [qw/account/] },
                }
            );
        my @targets = map { [ $_->credId, $_->account->ID, $_->purpose ] } $targets->all;
        $self->stash( targets => \@targets, targets_count => $targets->count );
        return;
    }

    for my $field ( qw/billId debtor date purpose value targetCredit/ ) {
        my $value = $self->param($field);
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
        $db->make_transfers( $to_pay_with => $self->param("billId") );
    }                  

    $self->redirect_to('home');

}

1;

