#!/usr/bin/perl

# This script was developed by Thorsten from the FHEM forum: https://forum.fhem.de/index.php/topic,69132.msg606372.html#msg606372
# Creates control file for tradfri FHEM modul

use IO::File;
use strict;
use warnings;

my @filelist2 = (
  "FHEM/.*.pm",
);


# Can't make negative regexp to work, so do it with extra logic
my %skiplist2 = (
# "www/pgm2"  => ".pm\$",
);

# Read in the file timestamps
my %filetime2;
my %filesize2;
my %filedir2;
foreach my $fspec (@filelist2) {
  $fspec =~ m,^(.+)/([^/]+)$,;
  my ($dir,$pattern) = ($1, $2);
  my $tdir = $dir;
  opendir DH, $dir || die("Can't open $dir: $!\n");
  foreach my $file (grep { /$pattern/ && -f "$dir/$_" } readdir(DH)) {
    next if($skiplist2{$tdir} && $file =~ m/$skiplist2{$tdir}/);
    my @st = stat("$dir/$file");
    my @mt = localtime($st[9]);
    $filetime2{"$tdir/$file"} = sprintf "%04d-%02d-%02d_%02d:%02d:%02d",
                $mt[5]+1900, $mt[4]+1, $mt[3], $mt[2], $mt[1], $mt[0];
				
	open(FH, "$dir/$file");
    my $data = join("", <FH>);
    close(FH);			
					
    $filesize2{"$tdir/$file"} = length($data); # $st[7];
    $filedir2{"$tdir/$file"} = $dir;
  }
  closedir(DH);
}

my %controls = (tradfri=>0);
foreach my $k (keys %controls) {
  my $fname = "controls_$k.txt";
  $controls{$k} = new IO::File ">$fname" || die "Can't open $fname: $!\n";
  if(open(ADD, "fhemupdate.control.$k")) {
    while(my $l = <ADD>) {
      my $fh = $controls{$k};
      print $fh $l;
    }
    close ADD;
  }
}

my $cnt;
foreach my $f (sort keys %filetime2) {
  my $fn = $f;
  $fn =~ s/.txt$// if($fn =~ m/.pl.txt$/);
 
  foreach my $k (keys %controls) {
    my $fh = $controls{$k};
    print $fh "UPD $filetime2{$f} $filesize2{$f} $fn\n"
  }

}


foreach my $k (keys %controls) {
  close $controls{$k};
}