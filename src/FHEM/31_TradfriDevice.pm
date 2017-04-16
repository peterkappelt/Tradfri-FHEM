#Git version: $Id$

package main;
use strict;
use warnings;

use JSON;
use Data::Dumper;

my %TradfriDevice_gets = (
	"deviceList"	=> ' ',
	"deviceInfo"	=> ' ',
	"satisfaction"  => "no"
);

my %TradfriDevice_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
);

my $tradfriGWAddress = '';
my $tradfriSecKey = '';

use constant{
        PATH_ROOT =>    '15001',
};

sub dbg{
        print("$_[0]\r\n");
}

sub coapCommand{
        my $method = $_[0];
        my $path = $_[1];
        my %data = %{$_[2]};

        print Dumper(%data);

        my $coapClientCMD = "coap-client -u Client_identity -k $tradfriSecKey -v 1 -m $method coaps://$tradfriGWAddress:5684/$path";

        if(%data){
                $coapClientCMD .= ' -f tmp';
                my $jsonData = JSON->new->utf8->encode(\%data);
                system("echo '$jsonData' > tmp");
        }

        my $return = `$coapClientCMD`;

        dbg($return);
        dbg("\r\n");


        my @retlines = split("\n", $return);

        if(scalar(@retlines) < 4){
                #we need at least four lines of response data.
                #the first three linesa re just status returns of the software
                #the last lines contains the actual json data
                return undef;
        }

        my $jsonData = JSON->new->utf8->decode($retlines[3]);

        return $jsonData;
}

#this returns the devices, which are couples to the hub
#it is an array, with one id per element
sub getDevices(){
        return coapCommand('GET', PATH_ROOT, {});
        #dbg(Dumper($retval));
}

#get the JSON hash of a device's path
#takes one argument: the device address
sub getDeviceInfo{
	return coapCommand('GET', PATH_ROOT . "/" . $_[0], {});
}

#get the device typpe
#you must pass the return code of getDeviceInfo as the first argument
sub getDeviceType{
	return $_[0]->{3}{1};
}

#get the device's manufacturer
#you must pass the return code of getDeviceInfo as the first argument
sub getDeviceManufacturer{
	return $_[0]->{3}{0};
}

# The output of the path ROOT_PATH/LAMP_ADDRESS looks like follows.
# We can just write single values to change the attributes

# $VAR1 = {
          # '9020' => 1492322690,
          # '9003' => 65537,
          # '9054' => 0,
          # '3311' => [
                      # {
                        # '9003' => 0,
                        # '5850' => 0,
                        # '5851' => 91
                      # }
                    # ],
          # '9019' => 1,
          # '3' => {
                   # '0' => 'IKEA of Sweden',
                   # '2' => '',
 
                  # '3' => '1.1.1.0-5.7.2.0',
                   # '6' => 1,
                   # '1' => 'TRADFRI bulb E27 opal 1000lm'
                 # },
          # '9001' => 'Fenster Links',
          # '9002' => 1492280964,
          # '5750' => 2
        # };


#turn a lamp on or off
#this requires two arguments: the lamp address and the on/off state (as 0 or 1)
sub lampSetOnOff{
        my $lampAddress = shift;
        my $onOffState = shift;

        my $jsonState = $onOffState ? 1:0;

        my $command = {
                '3311' => [
                        {
                                '5850' => $jsonState
                        }
                ]
        };

        coapCommand('PUT', "15001/$lampAddress", $command);
}

#set the dimming brightness of a lamp
#this requires two arguments: the lamp address and the dimming value, between 0 and 254 (including these values)
sub lampSetBrightness{
        my $lampAddress = shift;
        my $brightness = shift;

        if($brightness > 254){
                $brightness = 254;
        }
        if($brightness < 0){
                $brightness = 0;
        }

        #caution: we need an hash reference here, so it must be defined with $
        my $command = {
                '3311' => [
                        {
                                '5851' => $brightness
                        }
                ]
        };

        coapCommand('PUT', "15001/$lampAddress", $command);
}

sub TradfriDevice_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}      = 'TradfriDevice_Define';
    $hash->{UndefFn}    = 'TradfriDevice_Undef';
    $hash->{SetFn}      = 'TradfriDevice_Set';
    $hash->{GetFn}      = 'TradfriDevice_Get';
    $hash->{AttrFn}     = 'TradfriDevice_Attr';
    $hash->{ReadFn}     = 'TradfriDevice_Read';

    $hash->{AttrList} =
          "gatewayIP gatewaySecret "
        . $readingFnAttributes;
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

	if($attr{$hash->{name}}{gatewayIP} eq ''){
		$attr{$hash->{name}}{gatewayIP} = "Define Gateway IP!";
	}
	$tradfriGWAddress = $attr{$hash->{name}}{gatewayIP};
  
	if($attr{$hash->{name}}{gatewaySecret} eq ''){
                $attr{$hash->{name}}{gatewaySecret} = "Define Gateway Secret!";
        }
        $tradfriSecKey = $attr{$hash->{name}}{gatewaySecret};
 
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
	
	if($opt eq 'deviceList'){
		my @deviceIDList = getDevices();
		#ToDo: ugly construct -> why is the value-array in an array?
		return(join("\n", @{$deviceIDList[0]}));
	}elsif($opt eq 'deviceInfo'){
		my $jsonDeviceInfo = getDeviceInfo($hash->{deviceAddress});
		
		readingsSingleUpdate($hash, 'type', getDeviceType($jsonDeviceInfo), 1);
		readingsSingleUpdate($hash, 'manufacturer', getDeviceManufacturer($jsonDeviceInfo), 1);

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
		lampSetOnOff($hash->{deviceAddress}, 1);
		readingsSingleUpdate($hash, 'state', 'on', 1);
	}elsif($opt eq "off"){
		lampSetOnOff($hash->{deviceAddress}, 0);
		readingsSingleUpdate($hash, 'state', 'off', 1);
	}elsif($opt eq "dimvalue"){
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);
		lampSetBrightness($hash->{deviceAddress}, int($value));
		readingsSingleUpdate($hash, 'dimvalue', int($value), 1);
	}

	return undef;

	#return "$opt set to $value.";
}


sub TradfriDevice_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
        	if($attr_name eq "gatewayIP"){
			if($attr_value ne ''){
				$tradfriGWAddress = $attr_value;
			}else{
				return "You need to specify a gateway address!";
			}
		}elsif($attr_name eq "gatewaySecret"){
			if($attr_value ne ''){
                                $tradfriSecKey = $attr_value;
                        }else{
                                return "You need to specify a gateway secret!";
                        }
		}
	}
	return undef;
}

1;
