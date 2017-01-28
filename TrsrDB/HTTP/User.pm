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
    elsif ( my $token = $self->param('token') ) {
        my $pw = $self->param("password") // q{};
        if ( ($user->password//q{}) ne $token ) {
            $self->render( retry_msg => 'authfailure' );
            return;
        }
        elsif ( $pw ne ($self->param("samepassword") // q{}) ) {
            $self->render( retry_msg => "Passwords are different" );
            return;
        }
        $self->session("user_id" => $user_id );
        $user->salted_password($pw);
        $user->update();
        $self->redirect_to("home");
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

    $self->redirect_to('home');
    # $self->stash( retry_msg => 'loggedOut' );

}

1;

