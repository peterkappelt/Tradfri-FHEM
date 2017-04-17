# @author Peter Kappelt
# @date 17.4.2017 15:02

package main;
use strict;
use warnings;

use TradfriLib;

my %TradfriGateway_sets = (
	"ToBeDone"	=> ' ',
);

my %TradfriGateway_gets = (
	"deviceList"	=> ' ',
);

sub TradfriGateway_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGateway_Define';
	$hash->{UndefFn}    = 'TradfriGateway_Undef';
	$hash->{SetFn}      = 'TradfriGateway_Set';
	$hash->{GetFn}      = 'TradfriGateway_Get';
	$hash->{AttrFn}     = 'TradfriGateway_Attr';
	$hash->{ReadFn}     = 'TradfriGateway_Read';

	$hash->{Clients}	= "TradfriDevice";
	$hash->{MatchList} = { "1:TradfriDevice" => ".*" };

	#$hash->{AttrList} = "formal:yes,no " . $readingFnAttributes;
}

sub TradfriGateway_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 4) {
		return "too few parameters: define <name> TradfriGateway <gateway-ip> <gateway-secret>";
	}
	
	$hash->{name}  = $param[0];

	$hash->{gatewayAddress} = $param[2];
	$hash->{gatewaySecret} = $param[3];

	return undef;
}

sub TradfriGateway_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriGateway_Get($@) {
	my ($hash, @param) = @_;
	
	return '"get TradfriGateway" needs at least one argument' if (int(@param) < 2);
	
	my $name = shift @param;
	my $opt = shift @param;
	if(!$TradfriGateway_gets{$opt}) {
		my @cList = keys %TradfriGateway_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	if($opt eq 'deviceList'){
		my $deviceIDList = TradfriLib::getDevices($hash->{gatewayAddress}, $hash->{gatewaySecret});
			
		if($deviceIDList ~~ undef){
			return "Error while trying to fetch devices!";
		}

		my $returnUserString = "";

		for(my $i = 0; $i < scalar(@{$deviceIDList}); $i++){
			$returnUserString .= "- " . ${$deviceIDList}[$i] . "\n";
		}

		return $returnUserString;
	}

	return $TradfriGateway_gets{$opt};
}

sub TradfriGateway_Set($@) {
	my ($hash, @param) = @_;
	
	return '"set TradfriGateway" needs at least one argument' if (int(@param) < 2);
	
	my $name = shift @param;
	my $opt = shift @param;
	my $value = join("", @param);
	
	if(!defined($TradfriGateway_sets{$opt})) {
		my @cList = keys %TradfriGateway_sets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	$hash->{STATE} = $TradfriGateway_sets{$opt} = $value;
	
	return "$opt set to $value.";
}


sub TradfriGateway_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
		#if($attr_name eq "formal") {
		#	if($attr_value !~ /^yes|no$/) {
		#		my $err = "Invalid argument $attr_value to $attr_name. Must be yes or no.";
		#		Log 3, "TradfriGateway: ".$err;
		#		return $err;
		#	}
		#} else {
			return "Unknown attr $attr_name";
		#}
	}
	return undef;
}

1;