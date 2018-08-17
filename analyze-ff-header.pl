#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use List::MoreUtils qw( uniq );

my $HEADER_LENGTH_BYTES = 28;

sub parse_byte_range($)
{
    my ( $byte_range_str ) = @_;

    my @byte_range      = split( /\s*,\s*/, $byte_range_str );
    my @full_byte_range = (int 0) x $HEADER_LENGTH_BYTES;

    foreach my $byte ( @byte_range )
    {
        if( $byte =~ /^0x[0-9a-fA-F]+$/ )
        {
            my $index                = hex $byte;
            $full_byte_range[$index] = 1;
        }
        elsif( $byte =~ /^(0x[0-9a-fA-F]+)\s*[-]\s*(0x[0-9a-fA-F]+)$/ )
        {
            my $start_index = hex $1;
            my $end_index   = hex $2;

            foreach my $index ( int( $start_index ) .. int( $end_index ) )
            {
                $full_byte_range[$index] = 1;
            }
        }
        else
        {
            return;
        }
    }

    return \@full_byte_range;
}

sub get_header($)
{
    my ( $ff_file ) = @_;

    my $header =  `od -N 28 -t x1 $ff_file`;
       $header =~ s/\d{7}//g;
       $header =~ s/^\s+|\s+$//g;
       $header = join( ' ', split( /\s+/, $header ) );

    return $header;
}

sub print_offset_byte_frequencies($;$)
{
    my ( $ff_files, $byte_range ) = @_;

    my @indexes;

    foreach my $ff_file ( @$ff_files )
    {
        my $header       = get_header $ff_file;
        my @header_bytes = split( / /, $header );
        push( @{$indexes[$_]}, $header_bytes[$_] ) for 0 .. ( ( scalar @header_bytes ) - 1 )
    }

    foreach my $i ( 0 .. ( ( scalar @indexes ) - 1 ) )
    {
        my @byte_list   = @{$indexes[$i]};
        my $frequencies = {};

        foreach my $byte ( @byte_list )
        {
            if( !defined $frequencies->{$byte} )
            {
                $frequencies->{$byte} = 1;
            }
            else
            {
                $frequencies->{$byte}++;
            }
        }

        my @unique_bytes = uniq @byte_list;
        my $size      = scalar @unique_bytes;
        my $offset    = sprintf( '0x%X', $i );

        print "OFFSET $offset - $size UNIQUE BYTES:\n";
        print "    $_ ($frequencies->{$_})\n" for sort keys %$frequencies;
        print "\n";
    }
    
    return;
}

sub print_header_and_file_size($;$)
{
    my ( $ff_files, $byte_range ) = @_;

    foreach my $ff_file ( @$ff_files )
    {
        my $file_size = -s $ff_file;
        my $header    = get_header $ff_file;
        print "$ff_file\nFILE SIZE: $file_size bytes\nHEADER: $header\n\n";
    }

    return;
}

my $CMD_SWITCHES = {
    'freq' => {
        'sub' => \&print_offset_byte_frequencies,
        desc  => ( 'get the frequencies of bytes that occur at each offset ' .
                    'in the file headers.' ),
    },
    'size' => {
        'sub' => \&print_header_and_file_size,
        desc  => 'print the size and header of each file.',
    },
};

my $bname = basename $0;
my $usage = <<"EOL";
Usage: $bname -c <command> [-r <byte range>] <CoD4 pre-alpha root dir>
  <command> can be any of the following:
  [-r <byte range>] can be a comma-separated list of individual bytes
                    or byte ranges. Examples:
                      -r 0x2
                      -r 0xA,0xB
                      -r 0x1-0x3
                      -r 0x0-0x3,0x5-0x8,0xF
EOL

$usage .= "    $_ - $CMD_SWITCHES->{$_}->{desc}\n" for keys %$CMD_SWITCHES;

my $opts = {};
getopts( 'c:r:', $opts );

my $command     = $opts->{c} or die $usage;
my $command_sub = $CMD_SWITCHES->{$command}->{'sub'};
die "Invalid command: $command\n" unless $command_sub;

my $byte_range_str = $opts->{r};
my $byte_range     = [];

if( defined $byte_range_str )
{
    $byte_range = parse_byte_range $byte_range_str
        or die "Invalid byte range: $byte_range_str\n";
}

my @ff_files  = @ARGV;
my $num_files = scalar @ff_files;

print "Found $num_files .ff files.\n";

$command_sub->( \@ff_files, $byte_range );

exit 0;
