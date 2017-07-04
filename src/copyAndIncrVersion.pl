#!/usr/bin/perl -w
# @author Peter Kappelt

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);

if(scalar(@ARGV) < 2){
	print("Usage: copyAndIncrVersion.pl src-file dst-file\r\nIn the file, there must be a line, starting with \"# \@version\"\r\n");
	exit;
}

my $contentOriginal;
open(my $fhIn, '<', $ARGV[0]) or die "Can't open input file $ARGV[0]";
{
    local $/;
    $contentOriginal = <$fhIn>;
}
close($fhIn);

(my $versionLine) = ($contentOriginal =~ /(# \@version .*)/);

if($versionLine eq ""){
	print("No versionline was found\r\n");
	exit;
}
$versionLine =~ s/# \@version //;

print("Old version was \"$versionLine\"\r\n");

my ($versionFirstPortion, $temp, $versionLastPortion) = ($versionLine =~ /(.*)(\.)([^\.]+$)/);

if(!defined($versionLastPortion) || !looks_like_number($versionLastPortion)){
	print("The last part of the version doesn't seem to be a number!\r\n");
	exit;
}

$versionLastPortion++;
my $newVersion = $versionFirstPortion . "." . $versionLastPortion;

print("New version number is \"$newVersion\"\r\n");

$contentOriginal =~ s/# \@version .*/# \@version $newVersion/;

open(my $fhOut, '>', $ARGV[1]) or die "Could not open output file \"$ARGV[1]\": $!";
print $fhOut $contentOriginal;
close $fhOut;