use strict;

package TrsrDB::HTTP::Account;
use Mojo::Base 'Mojolicious::Controller';
use Carp qw(croak);

sub list {
    my $self = shift;

    my $accounts = $self->app->db->resultset("Account");
    my $user = $self->stash("user");
    my %args = $user->grade                      ? ()
             : $accounts->find( $user->user_id ) ? ( 'me.ID' => $user->user_id )
             :                                     ( type => q{} );
    $accounts = $accounts->search(\%args, {
        order_by => { -asc => [qw/type balance.even_until me.ID/] },
        prefetch => 'balance'
    });

    $self->stash( accounts => $accounts );

    return;

}

sub upsert {
    my $self = shift;

    my $db = $self->app->db;
    my $account_rs = $db->resultset("Account");
    my $account;
    if ( my $name = $self->stash("account") ) {
        $self->stash( id => $name );
        $account = $account_rs->find($name);
    }
    else {
        $self->stash( id => undef );
        $account = $account_rs->new({});
    }
    $self->stash( account => $account );

    my $iban = $self->param("IBAN") // $account->IBAN;
        
    if ( $self->req->method eq 'POST' ) {
        my $p = $self->req->params->to_hash;

        if ( ($p->{IBAN}//q{}) eq q{*} ) {
            $p->{IBAN} = q{};
        }
        elsif ( !$iban ) {
            delete $p->{IBAN};
        } 

        if ( $p->{ID} !~ m{ \A [a-z] \w+ \z }aixms ) {
            die "Invalid ID: Must consist of ascii letters/numbers/",
                "underscores, but always begin with a letter";
        }
 
        for my $field ($account->result_source->columns) {
            my $value = $p->{ $field };
            $account->$field($value);
        }

        $account->update_or_insert();    
        $self->redirect_to("home");

    }
    else {
        if ( defined( $iban ) ) {
            $iban = q{*} if !$iban;
            $account->IBAN($iban);
        }
        my @types = $account_rs->search({ type => { '!=' => q// } }, {
            columns => ['type'], distinct => 1
        })->get_column("type")->all;
        $self->stash( types => \@types );
    }

    return;
}

sub history {
    my $self = shift;
    my %query = ( account => $self->stash("account") );
    if ( my $p = $self->param("purpose") ) {
        # ...
    }
    my $history = $self->app->db->resultset("History")->search(
        TrsrDB::HTTP::process_table_filter_widget(
            $self, \%query,
            { order_by => { -desc => [qw/date/] } }
        )
    );

    $self->stash( history => $history );
}

sub transfer {
    my $self = shift;
    my $db = $self->app->db;
    my $account = $db->resultset("Account")->find( $self->stash("account") );
    
    my $credits_rs = $account->available_credits;
    my $arrears_rs = $account->current_arrears;

    my $credit_ids = $self->every_param('credits');
    my $arrear_ids = $self->every_param('debits');

    if ( $self->req->method eq 'POST' && @$credit_ids && @$arrear_ids ) {
        $db->make_transfers( $credit_ids => $arrear_ids );
    }

    if ( !( $credits_rs->count && $arrears_rs->count ) ) {
        $self->redirect_to('home');
        return;
    }

    $self->stash( credits => $credits_rs, arrears => $arrears_rs );

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

