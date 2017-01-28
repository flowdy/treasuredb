use strict;

package TrsrDB::User;
use Digest::SHA qw(hmac_sha256_hex);
use Moose;
use Carp qw(croak);
extends 'DBIx::Class::Core';

__PACKAGE__->table('web_auth');
__PACKAGE__->add_columns(qw/
    user_id  password
/);

__PACKAGE__->add_column(grade => {
    data_type => 'TINYINT',
    default_value => 0,
});

__PACKAGE__->add_column($_ => {
    is_nullable => 1
}) for qw/username email/;

__PACKAGE__->set_primary_key('user_id');

sub salted_password {
    my ($self, $password) = @_;
    if ( exists $_[1] ) {
        my $random_string = randomstring(8);
        return $self->password(
            $random_string."//".hmac_sha256_hex($password, $random_string)
        );
    }
    else {
         my @ret = reverse split m{//}, $self->password;
         $ret[1] //= undef;
         return reverse @ret;
    }
}

sub password_equals {
    my ($self, $password) = @_;
    my ($salt, $stored_password) = split m{//}, $self->password, 2;
    return hmac_sha256_hex($password, $salt) eq $stored_password;
}

sub sqlt_deploy_hook {
   my ($self, $sqlt_table) = @_;

   $sqlt_table->add_index(
        name => 'unique_mail',
        fields => ['email'],
        type => 'unique'
   );

}

my @chars = ( 0..9, "a".."z", "A".."Z" );
sub randomstring {
    my ($length) = @_;
    return join q{}, map { $chars[ int rand(62) ] } 1 .. $length;
}
