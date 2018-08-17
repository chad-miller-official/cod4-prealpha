#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use List::MoreUtils qw( uniq );

my $usage = 'Usage: ' . basename( $0 ) . " <CoD4 pre-alpha root dir> <header length>\n";

my $ff_dir        = $ARGV[0] or die $usage;
my $header_length = $ARGV[1] or die $usage;

die "Directory does not exist: $ff_dir\n" unless -e $ff_dir;
die "Header length must be an integer.\n" unless $header_length =~ /^\d+$/;

my @ff_files  = glob( '/home/chad/Downloads/CoD4_n253/*.ff' );
my $num_files = scalar @ff_files;
my @indexes;

foreach my $ff_file ( @ff_files )
{
    my $header =  `od -N $header_length -t x1 $ff_file`;
       $header =~ s/\d{7}//g;
       $header =~ s/^\s+|\s+$//g;

    my @header_bytes = split( /\s+/, $header );
    push( @{$indexes[$_]}, $header_bytes[$_] ) for 0 .. ( ( scalar @header_bytes ) - 1 )
}

foreach my $i ( 0 .. ( ( scalar @indexes ) - 1 ) )
{
    my @byte_list = uniq @{$indexes[$i]};
    my $size      = scalar @byte_list;
    my $offset    = sprintf( '0x%X', $i );
    print "OFFSET $offset - $size UNIQUE BYTES: " . join( ', ', @byte_list ) . "\n";
}

print "For $num_files .ff files.\n";

exit 0;
