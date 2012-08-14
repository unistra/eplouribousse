use Modern::Perl;
use Plack::Builder;
use Plack::Request;
use Eplouribousse;
use autodie;
use open qw< :std :utf8 >;
use utf8;

builder {
    # use Authenticator;
    # enable qw[ Authenticator::krb5 realm AD.EXAMPLE.FR ];
    enable qw[ Plack::Middleware::Static root public ]
    , path => qr{
	  (?: ^ /(images|js|css)/ )
	| (?: [.](css|js|png|html) $ )
    }x;
    $Eplouribousse::APP;
};
