# @author Peter Kappelt
# @date 17.4.2017 15:02

package TradfriLib;
use strict;
use warnings;
use JSON;
use Data::Dumper;

use constant{
		PATH_ROOT =>    '15001',
};

sub dbg{
	print("$_[0]\r\n");
}

sub coapCommand{
	my $gwAddress = $_[0];
	my $gwSecret = $_[1];

	my $method = $_[2];
	my $path = $_[3];
	my %data = %{$_[4]};

	if($gwAddress eq ''){
		print("COAP-Client (Tradfri): Gateway Address must be defined!\r\n");
		return undef;
	}

	if($gwSecret eq ''){
		print("COAP-Client (Tradfri): Gateway Secret must be defined!\r\n");
		return undef;
	}

	my $coapClientCMD = "coap-client -u Client_identity -k $gwSecret -v 1 -m $method coaps://$gwAddress:5684/$path";

	if(%data){
		$coapClientCMD .= ' -f tmp';
		my $jsonData = JSON->new->utf8->encode(\%data);
		system("echo '$jsonData' > tmp");
	}

	my $return = `$coapClientCMD`;

	print $coapClientCMD;

	#dbg($return);
	#dbg("\r\n");

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
sub getDevices{
	return coapCommand($_[0], $_[1], 'GET', PATH_ROOT, {});
}

#get the JSON hash of a device's path
#takes one argument: the device address
sub getDeviceInfo{
	return coapCommand($_[0], $_[1], 'GET', PATH_ROOT . "/" . $_[2], {});
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
		my $lampAddress = $_[2];
		my $onOffState = $_[3];

		my $jsonState = $onOffState ? 1:0;

		my $command = {
				'3311' => [
						{
								'5850' => $jsonState
						}
				]
		};

		coapCommand($_[0], $_[1], 'PUT', "15001/$lampAddress", $command);
}

#set the dimming brightness of a lamp
#this requires two arguments: the lamp address and the dimming value, between 0 and 254 (including these values)
sub lampSetBrightness{
		my $lampAddress = $_[2];
		my $brightness = $_[3];

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

		coapCommand($_[0], $_[1], 'PUT', "15001/$lampAddress", $command);
}

1;