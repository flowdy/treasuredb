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
    
    my $credits = $account->available_credits;
    my $arrears = $account->current_arrears;

    return $self->redirect_to('home')
        if !( $credits->count() && $arrears->count() );

    $self->stash( credits => $credits, arrears => $arrears );

    return if $self->req->method ne 'POST'; 

    $db->make_transfers(
        $self->every_param('credits')
     => $self->every_param('debits')
    );

    return;

}

sub report {
    my $self = shift;
    my $account = $self->app->db
                ->resultset("Account")
                ->find( $self->stash("account") )
                ;

    $self->stash( report => $account->report->search_rs(
        {}, { order_by => { -asc => [qw/date/] } }
    ) );

}

1;

