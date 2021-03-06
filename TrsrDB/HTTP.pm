use strict;

package TrsrDB::HTTP;
use TrsrDB::Error;
use Mojolicious 6.0;
use Mojolicious::Sessions;
use Mojo::Base 'Mojolicious';
use POSIX qw(strftime);

{ my $sql_trace;
  open my $dfh, '>', \$sql_trace;
  sub get_trace () {
      my $t = $sql_trace;
      $sql_trace = q{};
      seek $dfh, 0, 0;
      return \$t;
  }
  has db => sub {
      my $db;
      eval q{use TrsrDB \$db} or $@ && die $@;
      $db->storage->debugfh($dfh);
      return $db;
  };
}


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

  if ( $ENV{DBIC_TRACE} ) {
      $self->helper(sql_trace => \&get_trace);
  }
  else {
    $self->helper(sql_trace => \&_get_trace_placeholder);
  }

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

  my $check = $auth->under(sub {
      my $c = shift;
      return $c->stash('grade') || undef;
  })->get('/');
  $check->get('/bankStatement' => sub {
      my $c = shift;
      my $records = $c->app->db->resultset("ReconstructedBankStatement")
                  ->search( process_table_filter_widget($c, {}, { order => 'date' }) );
      $c->stash( records => $records );
      $c->render('bankStatement');
  });

  my $admin = $auth->under(sub {
      my $c = shift;
      return $c->stash('grade') > 1 || undef;
  });

  $admin->any('/admin')->to('admin#dash');
  $admin->any( [qw/GET POST/] => '/account/:account' => { account => undef })
      ->to('account#upsert');
  $admin->any( [qw/GET POST/] => '/:account/in')->to('credit#upsert');
  $admin->any( [qw/GET POST/] => '/:account/out')->to('debit#upsert');
  $admin->post('/:account/transfer')->to('account#transfer');
  $admin->any( [qw/GET POST/] => '/batch-processor' )->to('account#batch_processor');
  $admin->any( [qw/GET POST PATCH/] => '/credit/:id' )->to('credit#upsert');
  $admin->any( [qw/GET POST/] => '/credit')->to('credit#upsert');
  $admin->any( [qw/GET POST PATCH/] => '/debit/*id' )->to('debit#upsert');
  $admin->any( [qw/GET POST/] => '/debit')->to('debit#upsert');
  $admin->get('/:action')->to(controller => 'admin');

  $auth->get('/')->to('account#list')->name('home');

  my $account = $auth->get('/:account')->under(sub {
      my $c = shift;

      return 1 if $c->stash('grade');

      my $account = $c->stash('account');
      if ( my $acc = $c->app->db->resultset('Account')->find($account) ) {
          $c->stash( account => $acc );
          $account = $acc;
      }
      else {
          $c->reply->not_found;
          return;
      }

      return 1 if !$account->type;

      return $account->ID eq $c->stash("user")->user_id || undef;

  });
  $account->get('/credits')->to("credit#list");
  $account->get('/debits')->to("debit#list");
  $account->get('/:action')->to('account#');

  $r->any('/*whatever' => {whatever => ''} => sub {
      my $c        = shift;
      my $whatever = $c->param('whatever');
      $c->render(text => "/$whatever did not match.", status => 404);
  });
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

sub process_table_filter_widget {
    my $c = shift;
    my %query = $_[0] ? %{$_[0]} : ();
    my %options = $_[1] ? %{$_[1]} : ();
    $options{rows} //= $c->param("rows") // 100;

    if ( my $category = $c->param('category') ) {
        $query{category} = $category;
    }

    if ( my $purpose = $c->param('purpose') ) {
        $query{purpose} //= { -like => "%$purpose%" };
    }

    my $until;
    if ( $until = $c->param('until') ) {
        $query{date} = { '<=' => $until };
    }

    if ( my $from = $c->param('from') ) {
        if ( $until ) {
            $query{date}{'>='} = $from;
        }
        elsif ( $from =~ m{ \A \d{4} (-\d\d)? }xms ) {
            $query{date} = { -like => "$from%" };
        }
        else {
            $query{date} = { '>=' => $from };
        }
    }

    if ( my $page = $c->param("page") ) {
        $options{page} = $page;
    }

    return \%query, \%options;

}

sub _get_trace_placeholder { \<<'EOF'
In this area, the server can trace SQL commands executed to fulfill your request. If the admin wants that, they can run the server with environment variable DBIC_TRACE=1.
All substantial logic of Treasure DB is realized as triggers and views right in the database file. In consequence, you could do without this HTTP interface and input all SQL commands directly in a general-purpose SQLite3 user interface. Thus you would get essentially the same results, except they do not look as nice.
EOF
}
1;

__END__
  
