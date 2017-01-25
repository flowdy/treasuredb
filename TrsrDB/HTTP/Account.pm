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

sub upsert {
    my $self = shift;

    my $db = $self->app->db;
    my $account_rs = $db->resultset("Account");
    my $account;
    if ( my $name = $self->stash("account") ) {
        $self->stash( name => $name );
        $account = $account_rs->find($name);
    }
    else {
        $self->stash( name => undef );
        $account = $account_rs->new({});
    }
    $self->stash( account => $account );

    if ( $self->req->method eq 'POST' ) {
        for my $field ($account->result_source->columns) {
            my $value = $self->param($field);
            $account->$field($value);
        }
        $account->update_or_insert();    
        $self->redirect_to("home");
    }
    else {
        my @types = $account_rs->search({ type => { '!=' => q// } }, {
            columns => ['type'], distinct => 1
        })->get_column("type")->all;
        $self->stash( types => \@types );
    }

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

    if ( $self->req->method eq 'POST' ) {
        $db->make_transfers(
            $self->every_param('credits')
         => $self->every_param('debits')
        );
    }

    if ( !( $credits->count && $arrears->count ) ) {
        $self->redirect_to('home');
        return;
    }

    $self->stash( credits => $credits, arrears => $arrears );

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

