#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw( cwd );
use File::Basename;
use File::ReadBackwards;
use Getopt::Std;
use List::MoreUtils qw( uniq );

my $CWD                 = cwd( $0 );
my $HEADER_LENGTH_BYTES = 28;

my $FF_HEADER_LOCATION   = "$CWD/ff-headers";
my $FF_DEFLATED_LOCATION = "$CWD/ff-deflated";

# COMMON UTILITY FUNCTIONS

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

sub read_header($)
{
    my ( $ff_file ) = @_;

    my $ff_file_basename = basename $ff_file;
    my $header_file      = "$FF_HEADER_LOCATION/$ff_file_basename.bin";

    my $header = `od -t x1 $header_file`;
       $header =~ s/\d{7}//g;
       $header =~ s/^\s+|\s+$//g;

    my @header = split( /\s+/, $header );
    return \@header;
}

# COMMANDS

sub extract_headers($)
{
    my ( $ff_files ) = @_;

    foreach my $ff_file ( @$ff_files )
    {
        my $ff_extract_header = "$CWD/ff-extract-header.sh";
        my $output            = `$ff_extract_header -fp $ff_file`;
        print "Extracted header: $output\n";
    }

    return;
}

sub deflate($)
{
    my ( $ff_files ) = @_;

    foreach my $ff_file ( @$ff_files )
    {
        my $ff_deflate   = "$CWD/ff-deflate.sh";
        my $output       = `$ff_deflate -fp $ff_file`;
        my @output_lines = split( /\r/, $output );
        my $output_file  = $output_lines[( scalar @output_lines ) - 1];

        print "Deflated file: $output_file\n";
    }

    return;
}

sub print_offset_byte_frequencies($;$)
{
    my ( $ff_files, $byte_range ) = @_;

    my @indexes;

    foreach my $ff_file ( @$ff_files )
    {
        my $header = read_header $ff_file;
        push( @{$indexes[$_]}, $header->[$_] ) for 0 .. ( ( scalar @$header ) - 1 )
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
        my $size         = scalar @unique_bytes;
        my $offset       = sprintf( '0x%X', $i );

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
        my $file_basename = basename $ff_file;
        my $file_size     = -s "$FF_DEFLATED_LOCATION/$file_basename.bin";
        my $header        = read_header $ff_file;

        my @header_to_print;

        if( @$byte_range )
        {
            @header_to_print = grep { defined $_ } (
                map
                    { $byte_range->[$_] ? $header->[$_] : undef }
                    ( 0 .. $HEADER_LENGTH_BYTES )
            );
        }
        else
        {
            @header_to_print = @$header;
        }

        my $header_to_print_str = join( ' ', @header_to_print );

        print "$ff_file\nFILE SIZE: $file_size bytes\nHEADER: $header_to_print_str\n\n";
    }

    return;
}

sub print_footer_errors($;$)
{
    my ( $dumped_ff_files, $byte_range ) = @_;

    foreach my $dumped_ff_file ( @$dumped_ff_files )
    {
        my $back = File::ReadBackwards->new( $dumped_ff_file )
            or die "Error reading file $dumped_ff_file $!\n";

        my $line;
        my $do_loop = 1;

        print "$dumped_ff_file:\n";

        while( $do_loop && ( $line = $back->readline() ) )
        {
            if( $line =~ /^ERROR/ )
            {
                print $line;
            }
            elsif( $line =~ /^.+ERROR/ )
            {
                $line =~ s/^.+(ERROR.*)/$1/;
                print $line;
                $do_loop = 0;
            }

            my $unpacked = unpack( 'H*', $line );

            if( $unpacked =~ /ffffffff/ )
            {
                $do_loop = 0;
            }
        }

        print "\n";
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
    'errors' => {
        'sub' => \&print_footer_errors,
        desc  => ( 'print any error messages that appear in the footer of ' .
                   'each file.' ),
    },
    'extract-header' => {
        'sub' => \&extract_headers,
        desc  => 'extract headers from all fast file args.',
    },
    'deflate' => {
        'sub' => \&deflate,
        desc  => 'deflate all fast file args.',
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

print "Reading $num_files .ff files.\n\n";

$command_sub->( \@ff_files, $byte_range );

exit 0;
