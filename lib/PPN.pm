package PPN;
use Modern::Perl;
use Eplouribousse::Utils;
use YAML ();
use autodie;
use IO::All;

my %title_of;

sub from   { path_of ppn => @_ }
sub reader {
    open my $fh, from @_;
    $fh;
}

sub claims_for {
    my ( $ppn ) = @_;
    map { (split '/')[1] } glob "claim/*/$ppn";
}

sub load_index {
    %title_of or %title_of = do {
	open my $fh, 'ppn/index';
	map {
	    chomp;
	    split " ", $_, 2;
	} <$fh> 
    };
}

sub titles {
    load_index;
    values %title_of;
}

sub list {
    load_index;
    keys %title_of;
}

sub title_of {
    load_index;
    $title_of{ $_[0] };
}

sub with_localisations (&$) {
    my ( $code, $ppn ) = @_;
    my $reader = reader $ppn,'localisations';
    map {chomp;&$code} <$reader>;
}

sub localisations {
    with_localisations { split " ", $_, 2 } shift
}

sub involved_rcrs {
    with_localisations { (split " ", $_, 2)[0] } shift
}

sub data {
    my $ppn = shift;
    local $/;
    my $reader = reader $ppn,'data';
    YAML::Load <$reader>
}

1;

