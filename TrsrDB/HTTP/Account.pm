use strict;

package TrsrDB::HTTP::Account;
use Mojo::Base 'Mojolicious::Controller';
use Carp qw(croak);

sub list {
    my $self = shift;

    my $accounts = $self->app->db->resultset("Account");

    my %args = $self->stash("user")->grade ? () : ( type => undef );
    $accounts = $accounts->search(\%args, { order_by => { -asc => [qw/type ID/] } });

    $self->stash( accounts => $accounts );

    return;

}

sub history {
    my $self = shift;
    my $history = $self->app->db->resultset("History")->search({
        account => $self->stash("account")
    }, { order_by => { -desc => [qw/date/] } });
    $self->stash( history => $history );
}

sub transfer {
    my $self = shift;
    my $db = $self->app->db;
    my $account = $db->resultset("Account")->find( $self->stash("account") );
    
    if ( $self->req->method eq 'GET' ) {
        $self->stash(
            credits => $account->available_credits_rs,
            arrears => $account->current_arrears_rs,
        );
        return;
    }

    $db->make_transfers(
        $self->every_param('credits')
     => $self->every_param('debits')
    );

    return;

}
1;

