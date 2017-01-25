use strict;

package TrsrDB::HTTP::Credit;
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

    my $rs = $account->search_related(
        credits => {}, { order_by => { -desc => [qw/date/] } }
    );
    $self->stash( credits => $rs );

    return;

}

sub upsert {
    my $self = shift;
    
    my $db = $self->app->db;
    my $id = $self->stash("id");
    my $method = $id ? 'find_or_new' : 'new';
    my $credit = $db->resultset("Credit")->$method(
        { $id ? (credId => $id) : (), account => $self->stash("account") }
    );
    $self->stash( credit => $credit );

    if ( $self->req->method eq 'GET' ) {
        return;
    }

    for my $field ( qw/account date purpose value/ ) {
        my $value = $self->param($field);
        $credit->$field($value);
    }
    $credit->update_or_insert();

    my $to_revoke = $self->every_param("revoke");
    if ( @$to_revoke ) {
        $db->resultset("Transfer")->search({
            billId => $to_revoke, credId => $id
        })->delete;
    }

    my $to_spend_for = $self->every_param("spendFor");
    if ( @$to_spend_for ) {
        $db->make_transfers( $self->param("billId") => $to_spend_for);
    }                  

    $self->redirect_to('home');


}

1;

