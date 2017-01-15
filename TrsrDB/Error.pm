use 5.014;

package TrsrDB::Error {
use Moose;
extends 'Throwable::Error';

use overload eq => sub { ref($_[0]) eq $_[1] };

has http_status => (
    is => 'rw',
    isa => 'Num',
);

has _remote_stack_trace => (
    is => 'ro', isa => 'Str'
);

sub dump {
    my ($self, $with_internals) = @_;
    my $stack_trace = $self->stack_trace;
    my (@frames);
    while ( my $next = $stack_trace->next_frame ) {
        last if $next->package eq 'FTM::User::Interface'
             && $next->subroutine eq 'Try::Tiny::try';
        push @frames, $next;
    }
    return {
        (map { $_ => $self->$_ } qw(message user_seqno http_status)),
        $with_internals // 1 ? (
            _is_ftm_error => ref $self,
            _remote_stack_trace => join(
                "", map { $_->as_string . "\n" } @frames
            )
        ) : (),
        inner(),
    };
}

override as_string => sub {
    my $self = shift;
    if ( defined(my $rst = $self->_remote_stack_trace) ) {
        $rst =~ s{^}{[BACKEND] }mg;
        return $self->message.$rst;
    }    
    else { super(); }
};

__PACKAGE__->meta->make_immutable;

}

1;
