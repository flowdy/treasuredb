use strict;

package TrsrDB::HTTP::Credit;
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
        credits => TrsrDB::HTTP::process_table_filter_widget(
            $self, {}, { order_by => { -desc => [qw/date/] }}
        )
    );
    $self->stash( credits => $rs );

    return;

}

sub upsert {
    my $self = shift;
    
    my $db = $self->app->db;
    my $id = $self->stash("id");
    my $method = $id ? 'find_or_new' : 'new';
    my $credit = $db->resultset("Credit")->$method({
        $id ? (credId => $id) : (),
        account => $self->stash("account"),
        date => strftime("%Y-%m-%d", localtime)
    });
    $self->stash(
        credit => $credit,
        categories => $db->resultset("Category")->search_rs({}, {
            order_by => { -asc => [qw/ID/] }
        })
    );

    if ( $self->req->method eq 'GET' ) {
        return;
    }

    for my $field ( qw/account date purpose category value/ ) {
        my $value = $self->param($field);
        $value = undef if !length $value;
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

    for my $param ( grep { /^note\[/ } @{ $self->req->params->names } ) {
        my $note = $self->param($param) || next;
        s{^note\[}{} && s{\]$}{} for $param;
        $credit->search_related(
            outgoings => { billId => $param }
        )->update({ note => $note });
    }

    $self->redirect_to('home');


}

1;

