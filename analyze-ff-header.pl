#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use List::MoreUtils qw( uniq );

my $HEADER_LENGTH_BYTES = 28;
my @CONSTANT_OFFSETS    = (
    0x0,  # 00
    0x1,  # 00
    0x2,  # 01
    0x8,  # 00
    0x9,  # 00
    0xC,  # 00
    0x17, # 00
    0x18, # 00
);

sub parse_byte_range($)
{
    my ( $byte_range_str ) = @_;

    my @byte_range       = split( /\s*,\s*/, $byte_range_str );
    my @full_byte_range  = (int 0) x $HEADER_LENGTH_BYTES;
    $full_byte_range[$_] = 1 for map( hex, @byte_range );

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
    '-F' => {
        'sub' => \&print_offset_byte_frequencies,
        desc  => ( 'get the frequencies of bytes that occur at each offset ' .
                    'in the file headers.' ),
    },
    '-s' => {
        'sub' => \&print_header_and_file_size,
        desc  => 'print the size and header of each file.',
    },
};

my $bname = basename $0;
my $usage = <<"EOL";
Usage: $bname <command switch> [byte range] <CoD4 pre-alpha root dir>
  <command switch> can be any of the following:
  [byte range] can be a comma-separated list of individual bytes
    or byte ranges.
EOL

$usage .= "    $_ - $CMD_SWITCHES->{$_}->{desc}\n" for keys %$CMD_SWITCHES;

my $command_switch = $ARGV[0] or die $usage;

my $command_sub = $CMD_SWITCHES->{$command_switch}->{'sub'};
die "Invalid command: $command_switch\n" unless $command_sub;

my $byte_range_str;
my $ff_dir;

if( defined $ARGV[2] )
{
    $byte_range_str = $ARGV[1];
    $ff_dir         = $ARGV[2];
}
elsif( defined $ARGV[1] )
{
    $ff_dir = $ARGV[1];
}
else
{
    die $usage;
}

die "Directory does not exist: $ff_dir\n" unless -e $ff_dir;

my $byte_range;

if( defined $byte_range_str )
{
    $byte_range = parse_byte_range $byte_range_str;
    print int( $_ ) . ' ' for @$byte_range;
    print "\n";
}

my @ff_files  = glob '/home/chad/Downloads/CoD4_n253/*.ff';
my $num_files = scalar @ff_files;

print "Found $num_files .ff files.\n";

$command_sub->( \@ff_files, $byte_range );

exit 0;
