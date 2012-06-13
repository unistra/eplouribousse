package Authenticator;
use Modern::Perl;
use Authen::Simple::Kerberos;

sub krb5 {
    state $kerberos = Authen::Simple::Kerberos->new( @_ );
    qw< Auth::Basic authenticator >
    , sub { $kerberos->authenticate(@_[0..1]) }
}

1;
