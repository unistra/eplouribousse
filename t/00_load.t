#! /usr/bin/perl
use Test::More;
for (qw(
    Eplouribousse
    Eplouribousse::Utils
)) {
    eval "use $_";
    ok( !$@, "$_ loaded" );
}

done_testing;
