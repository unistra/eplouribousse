package Eplouribousse;
use autodie;
use Modern::Perl;
use File::Basename;
use File::Path qw< make_path >;
use Exporter qw< import >;
our @EXPORT = qw<
    path_of dir_path ppn_dir rcr_dir gate
    missing_in keys_multiv
    OK serve
    trim
    is_file is_dir append_to
>;


sub is_file {
    my $file = shift;
    -f $file or do {
        map { -d or make_path $_ } dirname $file;
        open my $fh,'>', $file;
    };
    $file;
}

sub is_dir {
    my $dir = shift;
    make_path $dir;
    -d $dir or make_path $dir or die $!;
    $dir;
}


sub append_to {
    my $file = shift;
    is_file $file;
    open my $fh,'>>',$file or die $!;
    say $fh $_ for @_;
}

sub missing_in {
    my $in = shift;
    grep { not exists $$in{$_} } @_
} 

sub keys_multiv {
    my $in = shift;
    grep { (!ref $$in{$_} ) || ( @{ $$in{$_} } > 1 ) } keys %$in;
} 


sub path_of {
    my $base = shift;
    join '/'
    , $base
    , substr( $_[0], 0, 3 )
    , @_;
}
sub dir_path {
    my $path = path_of @_;
    make_path $path;
    $path;
}
sub ppn_dir { dir_path ppn => @_ }
sub rcr_dir { dir_path rcr => @_ }
sub gate {
    my ( $mode, $key, $file, $id ) = @_;
    my $dir = dir_path $key, $id;
    $mode =~ s/^P// and make_path $dir;
    open my $fh, $mode, "$dir/$file";
    $fh
}

sub trim { s{ ^\s+ | \s+$ }//g }
sub OK    { 200 };
sub serve {
    state $header = 
    [ qw<
        Content-Script-Type text/javascript
        Content-Style-Type  text/css
        Content-Type >,   'text/html; charset=UTF-8'];

    [ OK, $header , [@_] ]
}


1;

