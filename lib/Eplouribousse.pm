package Eplouribousse;
use Modern::Perl;
use XML::Tag::html5;
use XML::Tag::html5_bootstrap;
use Plack::Builder;
use Plack::Request;
use YAML ();
use Perlude;
use Eplouribousse::Utils;
use autodie;
use RCR;
use PPN;
use open qw< :std :utf8 >;
use utf8;

sub nav_menu {
    # examples from http://twitter.github.com/bootstrap/examples/fluid.html
    my $menu = shift;
    # TODO: make it happen! +{ style => qq{background: color:white url("/static/logo.png")},
    a { +{qw< class brand href / >}, "Eplouribousse"}
    , div { +{class=>"nav-collapse"}
        , ul { +{class=>"nav"}
            , map { li { link_to @$_ } } @$menu
            # , li { +{class=> "active"}, link_to qw< #haha revendiquer > }
        }
    }
}

sub page {
    state $common = join ''
    , meta_name  (author => "Marc Chantreux")
    , import_js  ("/js/jquery-1.7.2.min.js")
    , import_css ("/theme.css")
    , import_css ("/bootstrap/css/bootstrap.css")
    , import_css ("/bootstrap/css/bootstrap-responsive.css");

    my $title = shift;
    my $code  = pop;
    my %arg  = @_;
    '<!DOCTYPE html>', html {
	head { title {$title}, $common },
	body {
            top_menu {
                nav_menu ( $arg{menu} || [] )
            }
	    , div {+{qw< class container-fluid>}
		, $code->()
            }
            # TODO: make it happen!
            # q{<hr style="width:100% "/>Eplouribousse, utilitaire pour le dédoublonnement des  périodiques}
	}
    }
}

sub html_hr_list {
    my ( $list , $wanted_fields ) = @_;
    my @fields = $wanted_fields
    ? @$wanted_fields
    : keys %{ $$list[0] };

    row { map { th{$_} } @fields },
    map {
	row { map { cell { $_ } } @{ $_ }{ @fields } }
    } @$list;

}

sub manager_menu () {
    [ [qw< /arbitration Arbitrage >]
    , [qw< /own/list    Instructions >]
    ];
}

sub investigations {
    my %investigation_for; 
    map {
        my ( $ppn, $rcr ) = reverse split '/';
        push @{ $investigation_for{ $ppn } }
        , $rcr;
    } glob "own/*/*";

    serve page "instructions"
    , sub {
        table { +{ class => "table"},
            map {
                my $ppn = $_;
                row { cell {
                    p{PPN::title_of $_}
                    , ul {
                        map { li{ link_to "/rcr/$_/own/$ppn", RCR::title_of $_ }  }
                        @{ $investigation_for{$ppn} }
                    }
                } }
            } keys %investigation_for;
        }
    }
}

sub homepage {
    serve page "welcome home"
    , menu => manager_menu
    , sub {
	my %rcr = RCR::db;
        table { +{ class => "table"},
            table_heads('rcr','total','revendications','instructions')

            , map {
                row {
                    cell { link_to "/rcr/home/$_", $rcr{$_} }
                    , cell { 0+ RCR::ppns $_ }
                    , cell { 0+ RCR::claims $_ }
                    , cell { 0+ RCR::owns $_ }
                }
            } keys %rcr;
        }
    }
}

sub link_to_claim { link_to "/rcr/$_[0]/claim/$_[1]", $_[2] }

sub arbitration {
    my $arbitration = shift;
    if ( delete $arbitration->{conflicts} ) {
        for my $ppn ( keys %$arbitration ) {
            my $rcr = $arbitration->{$ppn};
            is_file "own/$rcr/$ppn";
        }
    }

    my %claim = RCR::claims_by_ppn;
    my @conflicts = keys_multiv \%claim;
    my @orphans   = grep { not exists $claim{$_} } PPN::list;

    serve page "Arbitrage"
    , menu => manager_menu
    , sub {
	my @chunks;
	@conflicts and push @chunks
	, h1{"les conflits"}
        , input_form {
            dl {
                map {
                    my $ppn = $_;
                    dt { PPN::title_of  $ppn }
                    , dd {
                        map {
                            # TODO: css inside ? rlY ? 
                            span {+{ style => "padding-left: 10px"}, input_radio( $ppn, $_ ) }
                            , " "
                            , link_to_claim $_, $ppn,  RCR::title_of $_
                            , ( RCR::ready_to_investigate $_ ? ' (ok) ' : ' ' )
                        } @{$claim{$ppn}} 
                    }
                } @conflicts 
            }
            , input_submit conflicts => "valider les revendications"
        };
	@orphans and push @chunks
	, h1{"les orphelins"}
	, ul {
	    map {
		my $ppn = $_;
		my @rcrs = PPN::involved_rcrs $ppn;
		li { PPN::title_of($ppn), ' : ',
		    join ' , '
		    , map {
			join ''
			, link_to_claim $_, $ppn,  RCR::title_of $_
		    } @rcrs
		}
	    } @orphans
	};
	@chunks;
    }
}

sub html_compare {
    my %data = %{ $_[0] };
    my @fields = do {
	my %uniq = map { map {$_=>1} keys %$_ } values %data;
	sort keys %uniq;
    };
    my @ids    = sort keys %data;

    row { th {''} , map { th {$_} } @ids }
    , map {
        my $f = $_;
        row {
            th {$f}
            , map { cell {$data{$_}{$f}} } @ids
        }
    } @fields;
}

sub ppn_compare {
    my $ppn = shift;
    my $data = PPN::data $ppn or die;
    serve page "comparaison des RCR pour le PPN $ppn"
    , sub { table { html_compare $data } }
}

sub rcr_menu {
    [ ["/rcr/home/$_[0]","collections"]
    , ["/rcr/claims/$_[0]","revendications"]
    , ["/rcr/owns/$_[0]","instructions"]
    ]
}

sub rcr_page {
    my ( $rcr, $title, $content ) = @_;
    serve page $title
    , menu => rcr_menu($rcr)
    , $content
}

sub rcr_owns {
    my ( $rcr ) = @_;
    rcr_page $rcr, "instructions en cours", sub {
        ul { map {
            li { link_to "/rcr/$rcr/own/$_", PPN::title_of $_ }
        } RCR::owns $rcr }
    }
}

sub _list_of_claims {
    my ( $rcr ) = @_;
    if ( -e RCR::step_store $rcr ) {
        table { +{qw< class table >}
            , map { row { cell { link_to_claim $rcr, $_, "ordre" }
                    , cell { PPN::title_of $_ }
                }
            } RCR::claims $rcr
        }
    }
    else {
        input_form {
            table { +{qw< class table >}
                , ( map {
                    row{ cell { link_to_claim $rcr, $_, "ordre" }
                        , cell { input_check ppn => $_ }
                        , cell { " ", PPN::title_of $_ }
                    }
                } RCR::claims $rcr ) 
                , row { cell
                    { +{qw< colspan 3 >}
                    , input_submit qw< claim annuler > }
                }
                , row { cell
                    { +{qw< colspan 3 style text-align:center >}
                    , input_submit finalize => "finaliser les renvendications" }
                }
            }
        }
    }
}

sub rcr_claims {
    my ( $claim, $rcr ) = @_;
    $$claim{finalize} and is_dir RCR::step_store $rcr;

    for ( $claim->get_all('ppn') ) { unlink RCR::claim_store $rcr, $_ }
    my %others = RCR::claimed_by_others $rcr;

    rcr_page $rcr, revendications => sub {
        h1 {"Vos revendications"}
        , _list_of_claims( $rcr )
        , h1 {"revendications externes concernant vos collections"}
        , table {
            map {
                row { cell { PPN::title_of $_ }
                    , cell { list map RCR::title_of($_), @{ $others{$_} }  }
                }
            } keys %others
        }
    }
}


sub rcr_home {
    my ( $claim, $rcr ) = @_;
    for ( $claim->get_all('ppn') ) {
        open my $fh,'>', RCR::claim_store $rcr, $_
    }

    rcr_page $rcr, "page d'accueil", sub {
        input_form {
            input_submit (qw< claim revendiquer >)
           , table { map {
                   row{  cell { input_check ppn => $_ }
                       , cell { " ", PPN::title_of $_ }
                   }
               } RCR::unclaimed $rcr
           }
           ,input_submit (qw< claim revendiquer >)
        }
    }
}

sub page_not_found {
    my ( $path ) = @_;
    [ 404, []
    , [ page "page not found", sub { p{"impossible de trouver la page $path"} } ] ]
}

sub slurp {
    my ( $file ) = @_;
    my $fh;
    if ( ref $file ) { $fh = $file }
    else             {  open $fh, $file }
    local $/;
    <$fh>;
}

sub report_claim {

    my ( $claim, $storage ) = @_;

    # respect the investigation order
    my @investigators = sort { $$claim{$a}  <=> $$claim{$b} }
	map {
	    # ignore poor filling of the form
	    if ( grep { ($_) =~ /(\d+)/ } $$claim{$_} ) { $_ }
	    else { () }
	} keys %$claim;
    open my $fh,'>', $storage;
    say $fh $_ for @investigators;

    page "renvendication prise en compte"
    , sub {
	p {"si votre revendication est acceptee, les bibliotheques instruiront comme suit" }
	, list map { $RCR::title_of{$_} } @investigators
    }
}

sub claim_form {
    my ( $ppn, $rows ) = @_;
    page "revendication du ppn $ppn"
    , sub {
	h1{ "revendication de $ppn" }
	, p { PPN::title_of $ppn  }
	, p {"Indiquez le numéro d'ordre pour le complètement de cette publication (en tenant compte de l'état de collection)"}
	, link_to("/ppn/show/$ppn","comparaison détaillée") 
	, form {+{qw< method post >}
	    , table {
		table_heads
		    ( "ordre d'instruction"
		    , "publication"
		    , "état de collection" )
		, table_rows @$rows 
	    }
	    , input_submit ( qw< claim revendiquer > )
	    , input_submit ( qw< cancel annuler > )
	}
    }
}

sub claim_page {
    # TODO: choix par click sur la bib
    # TODO: suppression de la revendication
    my ( $claim, $rcr, $ppn ) = @_;
    my $storage = RCR::claim_store $rcr, $ppn;

    $$claim{claim} and return serve report_claim $claim, $storage;

    # already claimed investigators
    my @investigators;

    if ( $$claim{cancel} ) { unlink $storage }
    else {
	# first page loading : load previous claim if needed
	-f $storage and @investigators = do {
            open my $fh, $storage or die;
            map { chomp; $_ } <$fh>
        }
    }

    # involved sites
    my %loc = PPN::localisations $ppn;

    # investigation position
    my %position;

    # in the web page
    my @order_of_appearance = do {
	my $index = 1;
	if ( @investigators ) {
	    # if already claimed, memorize investigation position
	    %position = map { $_  => $index++ } @investigators
	}
	else {
	    # fist claim? current rcr at top
	    $position{ $rcr } = $index++
	}

	# show the rest randomly
	sort { ( $position{$a} || $index )
	<=>    ( $position{$b} || $index ) } keys %loc;
    };

    serve claim_form $ppn, 
    [ map {
	[ (join '', input_text $_ => ($position{ $_ } || ''))
	, $RCR::title_of{$_}
	, $loc{$_} ]
    } @order_of_appearance ];
}

sub _owns_in_body {
    my ( $body, $storage) = @_;
    my @owns;
    while ( my ( $k, $v ) = each %$body ) {
        next if $k ~~ [qw< own false >];
        my    ( $isa, $id, $key ) = split '/', $k;
        if    ( $isa eq  'vol' ) { $owns[$id]{$key} = $v }
        elsif ( $isa eq  'list' ) { }
        else  { die "$k -> $isa is not a good catch" }
    }
    for my $o ( @owns ) {
        for (@$o{qw< damage miss >}) {
            trim;
            $_ =
            { raw  => $_
            , list => [split /\s*[&]\s*/] }
        }
    }
    YAML::DumpFile $storage, @owns;
    @owns;
}

sub _stored_owns {
    my ( $_ ) = @_;
    -f && -s or return;
    YAML::LoadFile $_;
}

sub _get_owns {
    my ( $body, $rcr, $ppn ) = @_;
    my $storage = "own/$rcr/$ppn";
    $$body{own}
    ? _owns_in_body $body, $storage
    : _stored_owns $storage
}

sub _segment {
    state $center = {qw< style text-align:center >};
    my ( $rcr, $num, $previous ) = @_;
    my $form = "vol/$num";

    row { cell { a{+{name =>$_}, $num } }
        , cell { RCR::title_of $$previous{owner} }
        , cell { input_select "$form/complete", [ '', 0..20 ], $$previous{complete} }
        , cell { $center, input_keep_check $$previous{owner} , "$form/owner", $rcr }
        , cell { $center, input_keep_check $$previous{volume}, "$form/volume", "yes" }
        , cell { $center, input_check qw< false a > }
        , cell { input_text ( "$form/start"  => $$previous{start}       || '') }
        , cell { input_text ( "$form/end"    => $$previous{end}         || '') }
        , cell { input_text ( "$form/miss"   => $$previous{miss}{raw}   || '') }
        , cell { input_text ( "$form/damage" => $$previous{damage}{raw} || '') }
    }
}

sub own_page {
    my ( $body, $rcr, $ppn ) = @_;
    my @owns = _get_owns @_;

    # TODO: collection report
    # TODO: links to completion
    # TODO: list management
    # TODO: locked fields
    # TODO: resize tight columns

    rcr_page $rcr, "instructions des segments reliés", sub {
        input_form {
            h2{ PPN::title_of $ppn }
            # , p{ "instruction des segments non-reliés" }
            , p{ "instruction des segments" }
            , input_submit( own => "instruire" ) 
            , table { +{qw< class table-bordered style table-layout:fixed >}
                , table_heads
                ( 'numero'
                , 'instructeur'
                , 'complète'
                , 'présent' 
                , 'relié'
                , 'début'
                , 'fin'
                , 'exceptions'
                , 'dommages' ), map { _segment $rcr, $_, $owns[$_] } 0..20;
            }
            , input_submit( own => "instruire" ) 
        }
    }
}

RCR::load_titles;

our $APP = sub {
    my $env = shift;
    $_ = $$env{PATH_INFO};
    $_ eq '/'                        ? homepage         :
    m{^/ppn/show/(.*)}               ? ppn_compare $1   :
    m{^/rcr/owns/(.*)}               ? rcr_owns    $1   :  
    do { # here are the forms
        my $body = Plack::Request
        -> new( $env )
        -> body_parameters;

        $_ eq '/arbitration'             ? arbitration    $body       :
        $_ eq '/own/list'                ? investigations $body       :
        m{^/rcr/home/(.*)}               ? rcr_home    $body, $1      :  
        m{^/rcr/claims/(.*)}             ? rcr_claims  $body, $1      :  
        m{^/rcr/([^/]+)/claim/(.*)}      ? claim_page  $body, $1, $2  :
        m{^/rcr/([^/]+)/own/(.*)}        ? own_page    $body, $1, $2  :
        page_not_found $_
    }
};

