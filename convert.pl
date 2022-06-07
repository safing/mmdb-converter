#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );
use local::lib 'local';
use MaxMind::DB::Writer::Tree;
use Net::Works::Network;
use Data::Printer;
use Text::CSV_XS;

my ($inputFile, $outputFile, $ipver) = @ARGV;

my $blocks_csv = Text::CSV_XS->new(
{
  binary => 1,
});

open my $fh, "<:encoding(utf8)", $inputFile or die "$inputFile: $!";

say("converting " . $inputFile . " into " . $outputFile);

my $iprange;
my $country;
my $continent;
my $countryID;
my $latitude;
my $longitude;
my $inEU;
my $aso;
my $asn;
my $isAnycast;
my $isSatelliteProvider;
my $isAnonymousProxy;

if (not $inputFile) {
  die("Missing input file");
}

if (not $outputFile) {
  die("Missing output file");
}

if (not $ipver) {
  say("No ip version specified, using IPv4");
}

my $ip_version = 4;
if ($ipver == '6') {
  $ip_version = 6;
}

$blocks_csv->bind_columns(
  \$iprange,
  \$country,
  \$continent,
  \$countryID,
  \$latitude,
  \$longitude,
  \$inEU,
  \$asn,
  \$aso,
  \$isAnycast,
  \$isSatelliteProvider,
  \$isAnonymousProxy );

# Our top level data structure will always be a map (hash).  The MMDB format
# is strongly typed. Describe your data types here.
# See https://metacpan.org/pod/MaxMind::DB::Writer::Tree#DATA-TYPES

my %types = (
    continent => 'map',
    'code' => 'utf8_string',
    country => 'map',
    'iso_code' => 'utf8_string',
    inEU => 'boolean',
    location => 'map',
    latitude => 'float',
    longitude => 'float',
    autonomous_system_number => 'uint32',
    autonomous_system_organization => 'utf8_string',
    is_anycast => 'boolean',
    is_satellite_provider => 'boolean',
    is_anonymous_proxy => 'boolean'
);

my $tree = MaxMind::DB::Writer::Tree->new(
    # "database_type" is some arbitrary string describing the database.  At
    # MaxMind we use strings like 'GeoIP2-City', 'GeoIP2-Country', etc.
    database_type => 'My-IP-Data',

    # "description" is a hashref where the keys are language names and the
    # values are descriptions of the database in that language.
    description =>
        { en => 'My database of IP data' },

    # "ip_version" can be either 4 or 6
    ip_version => $ip_version,

    # add a callback to validate data going in to the database
    map_key_type_callback => sub { $types{ $_[0] } },

    # "record_size" is the record size in bits.  Either 24, 28 or 32.
    record_size => 32, # 32, #24,
    merge_strategy => "recurse"
);

while ($blocks_csv->getline( $fh ) ) {
  my $network = Net::Works::Network->new_from_string(
    string => $iprange,
  );

  $tree->insert_network( $network, {
    continent => {
      'code' => $continent,
    },
    country => {
      'iso_code' => $country,
      inEU => $inEU,
    },
    location => {
      latitude => $latitude,
      longitude => $longitude,
    },
    autonomous_system_number => $asn,
    autonomous_system_organization => $aso,
    is_anycast => $isAnycast,
    is_satellite_provider => $isSatelliteProvider,
    is_anonymous_proxy => $isAnonymousProxy,
  });
}

# Checking for End-of-file 
if (not $blocks_csv->eof)  
{ 
    $blocks_csv->error_diag(); 
} 
close $fh;

# Write the database to disk.
open $fh, '>:raw', $outputFile;
$tree->write_tree( $fh );
close $fh;
