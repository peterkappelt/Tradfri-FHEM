# @author Peter Kappelt
# @version 1.3

package main;
use strict;
use warnings;

use Data::Dumper;

use TradfriLib;

my %TradfriDevice_gets = (
	"deviceInfo"	=> ' ',
);

my %TradfriDevice_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
);

sub TradfriDevice_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriDevice_Define';
	$hash->{UndefFn}    = 'TradfriDevice_Undef';
	$hash->{SetFn}      = 'TradfriDevice_Set';
	$hash->{GetFn}      = 'TradfriDevice_Get';
	$hash->{AttrFn}     = 'TradfriDevice_Attr';
	$hash->{ReadFn}     = 'TradfriDevice_Read';

	$hash->{Match} = ".*";

	#$hash->{AttrList} = "gatewayIP gatewaySecret " . $readingFnAttributes;
}

sub TradfriDevice_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 3) {
		return "too few parameters: define <name> TradfriDevice <DeviceAddress>";
	}
   
	$hash->{name}  = $param[0];
	$hash->{deviceAddress} = $param[2];
 
	#define empty readings
	readingsSingleUpdate($hash, "state", '???', 0);
	readingsSingleUpdate($hash, "dimvalue", '???', 0);

	AssignIoPort($hash);

	return undef;
}

sub TradfriDevice_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriDevice_Get($@) {
	my ($hash, @param) = @_;
	
	return '"get TradfriDevice" needs at least one argument' if (int(@param) < 2);
	
	my $name = shift @param;
	my $opt = shift @param;
	if(!$TradfriDevice_gets{$opt}) {
		my @cList = keys %TradfriDevice_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	if($opt eq 'deviceInfo'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if($jsonDeviceInfo ~~ undef){
			return "Error while fetching device info!";
		}

		readingsSingleUpdate($hash, 'type', TradfriLib::getDeviceType($jsonDeviceInfo), 1);
		readingsSingleUpdate($hash, 'manufacturer', TradfriLib::getDeviceManufacturer($jsonDeviceInfo), 1);

		return(Dumper($jsonDeviceInfo));
	}

	return $TradfriDevice_gets{$opt};
}

sub TradfriDevice_Set($@) {
	my ($hash, @param) = @_;
	
	return '"set TradfriDevice" needs at least one argument' if (int(@param) < 2);

	my $argcount = int(@param);
	
	my $name = shift @param;
	my $opt = shift @param;
	my $value = join("", @param);
	
	if(!defined($TradfriDevice_sets{$opt})) {
		my @cList = keys %TradfriDevice_sets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	$hash->{STATE} = $TradfriDevice_sets{$opt} = $value;

	if($opt eq "on"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		TradfriLib::lampSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, 1);
		readingsSingleUpdate($hash, 'state', 'on', 1);
	}elsif($opt eq "off"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		TradfriLib::lampSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, 0);
		readingsSingleUpdate($hash, 'state', 'off', 1);
	}elsif($opt eq "dimvalue"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);
		TradfriLib::lampSetBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, int($value));
		readingsSingleUpdate($hash, 'dimvalue', int($value), 1);
	}

	return undef;

	#return "$opt set to $value.";
}


sub TradfriDevice_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
#		if($attr_name eq "gatewayIP"){
#			if($attr_value ne ''){
#			}else{
#				return "You need to specify a gateway address!";
#			}
#		}elsif($attr_name eq "gatewaySecret"){
#			if($attr_value ne ''){
#			}else{
#				return "You need to specify a gateway secret!";
#			}
#		}
	}
	return undef;
}

1;
