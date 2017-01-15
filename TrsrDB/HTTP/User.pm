use strict;

package TrsrDB::HTTP::User;
use Mojo::Base 'Mojolicious::Controller';
#use Carp qw(croak);

sub login {
    my $self = shift;
    my $user_id = $self->param('user') // return;
    my $db      = $self->app->db;

    my $password        = $self->param('password');
    my $user = $db->resultset("User")->find(
        $user_id =~ m{@} ? { email => $user_id } : $user_id
    );
    
    if ( !$user ) {
        $self->render( retry_msg => 'authfailure' );
        return;
    }
    elsif ( $password && $user->password_equals($password) ) {
        $self->session("user_id" => $user_id );
        $self->redirect_to("home");
    }
    else {
        $self->render( $password ? (retry_msg => 'authfailure') : () );
    }

}

sub logout {
    my ($self) = @_;

    $self->session(expires => 1);

    # $self->stash( retry_msg => 'loggedOut' );

}

1;

