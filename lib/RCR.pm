package RCR;
use Eplouribousse::Utils;
use Modern::Perl;
use File::Path qw< make_path >;
use Perlude;
# use autodie;
use PPN; # TODO: holy shit: ppns ! 
use IO::All;

our %title_of;

sub step_store  { join '/' => qw<  step rcr >, @_ }
sub ready_to_investigate  { -d step_store shift }

sub claim_store { join '/', claim => @_ }
sub filename { m<([^/]+)$> }

sub from  { path_of rcr => @_ }
sub ppns  {
    my $file = from @_ => 'ppn';
    open my $fh,$file or return ();
    map {
        chomp;
        $_
    } <$fh>
} 
sub load_titles {
    %title_of or %title_of = map { chomp; split /;/ } io("rcr/index")->chomp->slurp
}

sub db       { load_titles; %title_of        }
sub codes    { load_titles; keys   %title_of }
sub titles   { load_titles; values %title_of }
sub title_of { load_titles; $title_of{$_[0]} }
sub claims   { map { m{([^/]+)$} } glob "claim/$_[0]/*" }
sub owns     { map { m{([^/]+)$} } glob "own/$_[0]/*" }
sub unclaimed  {
    my ( $rcr ) = @_;
    my  $claims = [claims $rcr];
    grep !($_ ~~ $claims), ppns $rcr
}

sub claims_by_ppn {
    my %claim;
    map {
	my ( undef, $rcr, $ppn ) = split "/";
        ( glob "own/*/$ppn" ) or
            push @{  $claim{ $ppn } }, $rcr;
    } glob("claim/*/*");
    %claim;
}

# TODO: any xs on cpan? 
sub claims_conflicts { keys_multiv {claims_by_ppn} }

sub claimed_by_others {
    my ( $rcr ) = @_;
    map { $_ => [ grep {$_ ne $rcr } PPN::claims_for $_ ] } claims $rcr;
}


sub can_claim (_) {
    my $rcr  = shift or die;
    -d || make_path $_ for "claim/$rcr";
}

sub everyone_can_claim (_) { map can_claim, codes }

1; 
