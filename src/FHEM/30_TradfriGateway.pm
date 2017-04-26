# @author Peter Kappelt
# @version 1.6

package main;
use strict;
use warnings;

use TradfriLib;

my %TradfriGateway_sets = (
	"ToBeDone"	=> ' ',
);

my %TradfriGateway_gets = (
	'deviceList'	=> ' ',
	'groupList'		=> ' ',
	'coapClientVersion'		=> ' ',
);

sub checkCoapClient{
	#check, if coap-client software exists. Set the Reading 'coapClientVersion' to the first line of the programm call's output
	my $coapClientReturnMessage = `coap-client 2>&1`;
	if($coapClientReturnMessage eq ''){
		#empty return -> error
		$_[0]->{canConnect} = 0;
		return "UNKNOWN";
	}else{
		readingsSingleUpdate($_[0], 'coapClientVersion', (split(/\n/, $coapClientReturnMessage))[0], 0);
		$_[0]->{canConnect} = 1;
		return (split(/\n/, $coapClientReturnMessage))[0];
	}
}

sub TradfriGateway_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGateway_Define';
	$hash->{UndefFn}    = 'TradfriGateway_Undef';
	$hash->{SetFn}      = 'TradfriGateway_Set';
	$hash->{GetFn}      = 'TradfriGateway_Get';
	$hash->{AttrFn}     = 'TradfriGateway_Attr';
	$hash->{ReadFn}     = 'TradfriGateway_Read';

	$hash->{Clients}	= "TradfriDevice:TradfriGroup";
	$hash->{MatchList} = {
			"1:TradfriDevice" => "D.*" ,
			"2:TradfriGroup" => "G.*" ,
			};
}

sub TradfriGateway_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 4) {
		return "too few parameters: define <name> TradfriGateway <gateway-ip> <gateway-secret> [<coap-client-directory>]";
	}
	
	$hash->{name}  = $param[0];

	$hash->{gatewayAddress} = $param[2];
	$hash->{gatewaySecret} = $param[3];

	if(int(@param) > 4){
		#there was a fifth parameter
		#it is the path to the coap client, add it to the environments path
		$ENV{PATH}="$ENV{PATH}:" . $param[4];
	}

	checkCoapClient($hash);

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
			my $deviceInfo = TradfriLib::getDeviceInfo($hash->{gatewayAddress}, $hash->{gatewaySecret}, ${$deviceIDList}[$i]);
			$returnUserString .= "- " . 
				${$deviceIDList}[$i] . 
				": " . 
				TradfriLib::getDeviceManufacturer($deviceInfo) .
				" " .
				TradfriLib::getDeviceType($deviceInfo) .
				" (" .
				TradfriLib::getDeviceName($deviceInfo) .
				")" .
				"\n";
		}

		return $returnUserString;
	}elsif($opt eq 'groupList'){
		my $groupIDList = TradfriLib::getGroups($hash->{gatewayAddress}, $hash->{gatewaySecret});

		if($groupIDList ~~ undef){
			return "Error while fetching groups!";
		}

		my $returnUserString = "";

		for(my $i = 0; $i < scalar(@{$groupIDList}); $i++){
			my $groupInfo = TradfriLib::getGroupInfo($hash->{gatewayAddress}, $hash->{gatewaySecret}, ${$groupIDList}[$i]);

			$returnUserString .= "- " .
				${$groupIDList}[$i] .
				": " .
				TradfriLib::getGroupName($groupInfo);

		}

		return $returnUserString;
	}elsif($opt eq 'coapClientVersion'){
		return checkCoapClient($hash);
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
		#	return "Unknown attr $attr_name";
		#}
	}
	return undef;
}

1;