use strict;

package TrsrDB::HTTP;
use TrsrDB::Error;
use Mojolicious 6.0;
use Mojolicious::Sessions;
use Mojo::Base 'Mojolicious';
use POSIX qw(strftime);

has db => sub {
    my $db;
    eval q{use TrsrDB \$db} or $@ && die $@;
    return $db;
};

# This method will run once at server start
sub startup {
  my $self = shift;

  $self->secrets([rand]);
  $self->sessions->cookie_name('TrsrDB');

  $self->config(
      hypnotoad => {
          listen => [ $ENV{MOJO_LISTEN} ],
          pid_file => $ENV{PIDFILE},
          workers => 2,
  });

  $self->defaults(
      layout => 'default',
      user => undef,
  );

  $self->helper(money => sub {
      my (undef, $cent) = @_;
      return if !defined $cent;
      my $c100 = $cent =~ s{ (\d{0,2}) \z }{}xms && sprintf("%02d", $1); 
      $cent ||= 0;
      return qq{<strong>$cent</strong>.$c100};
  });
  $self->helper(nl2br => sub {
      pop =~ s{\n}{<br>}grms;
  });

  if ( my $l = $ENV{LOG} ) {
      use Mojo::Log;
      open my $fh, '>', $l or die "Could not open logfile $l to write: $!";
      $self->log( Mojo::Log->new( handle => $fh, level => 'warn' ) );
  }

  unshift @{$self->static->paths}, $self->home->rel_dir('site');

  $self->helper( 'reply.client_error' => \&prepare_client_error );

  $self->hook( before_render => \&restapi_reply_jsonifier );

  # Router
  my $r = $self->routes->under(\&initialize_stash);
  $r->any( [qw/GET POST/] => "/login" )->to("user#login", retry_msg => 0 );

  my $auth = $r->under(\&require_user_otherwise_login_or_fail);

  $auth->get( '/logout' )->to("user#logout");

  my $check = $auth->under(sub { shift->stash('grade') })->get('/');
  $check->get('/bankStatement' => sub {
      my $c = shift;
      $c->stash( records => $c->app->db->resultset("ReconstructedBankStatement") );
      $c->render('bankStatement');
  });

  my $admin = $auth->under(sub { shift->stash('grade') > 1 });
  $admin->any('/admin')->to('admin#dash');
  $admin->post('/:account/in')->to('credit#upsert');
  $admin->post('/:account/out')->to('debit#upsert');
  $admin->get('/:account/credits')->to('credit#list');
  $admin->get('/:account/debits')->to('debit#list');
  $admin->post('/:account/transfer')->to('account#transfer');
  $admin->any( [qw/GET POST PATCH/] => '/credit/:id' )->to('credit#upsert');
  $admin->post('/credit')->to('credit#upsert');
  $admin->any( [qw/GET POST PATCH/] => '/debit/*id' )->to('debit#upsert');
  $admin->post('/debit')->to('debit#upsert');
  $admin->get('/:action')->to(controller => 'admin');

  $auth->get('/')->to('account#list')->name('home');

  my $account = $auth->get('/:account')->under(sub {
      my $c = shift;

      my $account = $c->stash('account');
      if ( my $acc = $c->app->db->resultset('Account')->find($account) ) {
          $c->stash( account => $acc );
          $account = $acc;
      }
      else {
          $c->reply->not_found;
          return;
      }

      return $account->type ? $c->stash('grade') : 1;

  });
  $account->get('/in')->to("credit#upsert");
  $account->get('/out')->to("debit#upsert");
  $account->get('/:action')->to('account#');

}

my $started_time;
BEGIN { $started_time = scalar localtime(); }
sub get_started_time { $started_time; }

sub initialize_stash {
    my $c = shift;

    my $ct = $c->req->headers->content_type;

    $c->stash(
        is_restapi_req => $c->accepts('', 'json' )
                       || $ct && $ct ne 'application/x-www-form-urlencoded',
        current_time => strftime('%Y-%m-%d %H:%M:%S', localtime time),
    );

    return 1;

}

sub require_user_otherwise_login_or_fail {
    my $c = shift;

    my $is_restapi_req = $c->stash('is_restapi_req');

    if ( my $u = authenticate_user($c) ) {
        $c->stash( user => $u );
        $c->stash( grade => $u->grade );
        return 1;
    }

    elsif ( !$is_restapi_req && $c->req->method eq "GET" ) {
        $c->redirect_to("/login");
    }

    else {
        $c->res->code(401);
    }

    return undef;

}
# Rely on Mojolicious in that the session cookie be cryptographically
# protected against manipulation (HMAC-SHA1 signature). Hence, if the
# user id is defined, the user has certainly logged in properly.
# Refer to `perldoc Mojolicious::Controller` if interested.
# If the REST application programing interface is used, there is no
# cookie. To stay "RESTful", we rely on HTTP header "Authentification".
      
sub authenticate_user {
    my $c = shift;

    my ($user, my $password)
        = split /:/, ( $c->req->url->to_abs->userinfo // q{} ), 2;

    my $further_check;

    if ( $user ) { $further_check = 1 }
    elsif ( $user = $c->session('user_id') ) {}
    
    $user &&= $c->app->db->user($user) or return; 

    if ( $further_check ) {
        $user->password_equals($password) or return;
        $c->stash("user" => $user);
    }

    return $user;

}

sub prepare_client_error {
    my $c = shift;
    my $x = @_ > 1 ? { @_ } : shift;
    my %args;

    # Case 1: We have got a genuine application error object of
    #         which we know the interface.
    if ( (my $xclass = ref $x) =~ s{^TrsrDB::Error\b}{} ) {
        # consider rather Scalar::Util::blessed ... Yes, I did
        $xclass =~ s{^::}{};
        %args = (
            %{ $x->dump(0) },
            error => $xclass || "General error",
        );
    }

    # Case 2: We have got a plain hash of arguments to use directly
    elsif ( ref $x eq 'HASH' ) {
        %args = ( (map { $_ => undef } qw(message error)), %$x);
    }

    # Otherwise, we have got an exception thrown from other, third-party 
    # code. You should design your production-mode exception template so
    # that it displays only $error and $message, not $exception, because
    # this might allow potential attackers to examine your server's
    # vulnerabilities.
    else {
        my $u = $c->stash("user");
        $c->stash(
            error => "Internal server error",
            message => $u && $u->can_admin ? (ref $x ? "$x" : $x)
                     : "Oops, something went wrong. (A more detailed "
                     . "error message logged server-side. Ask the admin.)"
                     ,
        );
        return;
    }

    $c->res->code( delete $args{http_status} // 500 );
    return $c->render( template => 'exception.production', %args );

}

sub restapi_reply_jsonifier {
    my ($c, $args) = @_;

    return if !$c->stash('is_restapi_req')
           || $args->{json};

    my %stash = ( %{ $c->stash }, %$args );
    delete @stash{ # general slots of internal interest ...
        qw(snapshot user template is_restapi_req layout
           hoster_info cb action controller
        ),
        grep { /^mojo\./ } keys %stash
    };

    $args->{json} = \%stash;

}

sub render_online_help {
    require Text::Markdown;
    my $c = shift;

    my $file = $c->stash("file");

    if ( $file =~ m{(^|\/)\.} ) {
        return $c->reply->not_found;
    }
    elsif ( $file =~ m{\.(\w{3,4})$} ) {
        return $c->reply->static( "../doc/online-help/" . $file );
    }

    $file = $c->app->home->rel_file(
        "doc/online-help/" . ( $file || "faq" ) . ".md"
    );

    open my $fh, '<', $file or return $c->reply->not_found;
    binmode $fh, ':utf8';

    $c->stash( layout => undef ) if $c->param('bare');
    $c->render( template => 'online_help', file => $file );

}

1;

__END__
  
