# @author Peter Kappelt
# @version 1.16.dev-cf.2

package TradfriLib;
use strict;
use warnings;
use JSON;
use Data::Dumper;

use constant{
	PATH_DEVICE_ROOT =>		'15001',
	PATH_GROUP_ROOT =>		'15004',
	PATH_MOODS_ROOT =>		'15005',
};

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

	my $coapClientCMD = "timeout 5s coap-client -u Client_identity -k $gwSecret -v 1 -m $method coaps://$gwAddress:5684/$path";

	if(%data){
		my $jsonData = JSON->new->utf8->encode(\%data);
		$coapClientCMD = "echo '$jsonData' | " . $coapClientCMD . " -f -";
	}

	$coapClientCMD = $coapClientCMD . " 2>/dev/null";

	my $return = `$coapClientCMD`;

	#print $coapClientCMD;

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
#first arg: gateway address
#second arg: gateway secret
sub getDevices{
	return coapCommand($_[0], $_[1], 'GET', PATH_DEVICE_ROOT, {});
}

#get the JSON hash of a device's path
#takes three arguments:
#first arg: gateway address
#second arg: gateway secret
#third arg: device address
sub getDeviceInfo{
	return coapCommand($_[0], $_[1], 'GET', PATH_DEVICE_ROOT . "/" . $_[2], {});
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

#get the user defined name of the device
#you must pass the return code of getDeviceInfo as the first argument
sub getDeviceName{
	return $_[0]->{9001};
}

#get the device's brightness
#you must pass the return code of getDeviceInfo as the first argument
sub getDeviceBrightness{
	return $_[0]->{3311}[0]->{5851};
}

#get the device's on/ off state
#you must pass the return code of getDeviceInfo as the first argument
sub getDeviceOnOff{
	return $_[0]->{3311}[0]->{5850};
}

#get the timestamp, when the device was created
#you must pass the return code of getGroupInfo as the first argument
sub getDeviceCreatedAt{
	return $_[0]->{9002};
}

#get the  software version of the device
#you must pass the return code of getGroupInfo as the first argument
sub getDeviceSoftwareVersion{
	return $_[0]->{3}{3};
}

#get, whether the device is reachable
#you must pass the return code of getGroupInfo as the first argument
sub getDeviceReachableState{
	return $_[0]->{9019};
}

#get the timestamp, when the device was last seen by the gateway
#you must pass the return code of getGroupInfo as the first argument
sub getDeviceLastSeen{
	return $_[0]->{9020};
}

#get the device color code
#if the device cannot change its color, this function returns 0
#you must pass the return code of getGroupInfo as the first argument
sub getDeviceColor{
	if(exists($_[0]->{3311}[0]->{5706})){
		return $_[0]->{3311}[0]->{5706};
	}
	return 0;
}

#this returns the groups, which are configured on the hub
#it is an array, with one group id per element
#first arg: gateway address
#second arg: gateway secret
sub getGroups{
	return coapCommand($_[0], $_[1], 'GET', PATH_GROUP_ROOT, {});
}

#get the JSON hash of a group's path
#takes three arguments:
#first arg: gateway address
#second arg: gateway secret
#third arg: group address
sub getGroupInfo{
	return coapCommand($_[0], $_[1], 'GET', PATH_GROUP_ROOT . "/" . $_[2], {});
}

#get the user defined name of the group
#you must pass the return code of getGroupInfo as the first argument
sub getGroupName{
	return $_[0]->{9001};
}

#get the device IDs of all group members
#you must pass the return code of getGroupInfo as the first argument
#it returns an array reference containing all group IDs
sub getGroupMembers{
	return $_[0]->{9018}{15002}{9003};
}

#get the current dimming value of a group
#
# CAUTION: the parameters are different than those of the other functions
#
#takes three arguments:
#first arg: gateway address
#second arg: gateway secret
#third arg: return of getGroupInfo
sub getGroupBrightness{
	#the brightness-value off the group can not just be returned
	#it is a write-only key, so it contains the last written value (but not the actual value)
	#read the brightnesses of the member devices and return their mean
	my @groupMembers = @{getGroupMembers($_[2])};

	my $validDeviceCount = 0;
	my $deviceBrightnessMean = 0;

	for(my $i = 0; $i < scalar(@groupMembers); $i++){
		my $currentDeviceInfo = getDeviceInfo($_[0], $_[1], $groupMembers[$i]);
		
		#only if key 3311 exists, it is a device that contains a dimming value (a dimmer doesn't contain one)
		if(exists($currentDeviceInfo->{3311})){
			$validDeviceCount++;
			$deviceBrightnessMean += $currentDeviceInfo->{3311}[0]->{5851};
		}
	}

	return int($deviceBrightnessMean / $validDeviceCount + 0.5);

	#return $_[0]->{5851};
}

#get the current on/off state of a group
#
# CAUTION: the parameters are different than those of the other functions
#
#you must pass the return code of getGroupInfo as the first argument
#takes three arguments:
#first arg: gateway address
#second arg: gateway secret
#third arg: return of getGroupInfo
sub getGroupOnOff{
	#the on/off-value off the group can not just be returned
	#it is a write-only key, so it contains the last written value (but not the actual value)
	#read the state of the member devices and return 1, if at least one device is on
	my @groupMembers = @{getGroupMembers($_[2])};

	for(my $i = 0; $i < scalar(@groupMembers); $i++){
		my $currentDeviceInfo = getDeviceInfo($_[0], $_[1], $groupMembers[$i]);
		
		#only if key 3311 exists, it is a device that contains a dimming value (a dimmer doesn't contain one)
		if(exists($currentDeviceInfo->{3311})){
			return 1 if $currentDeviceInfo->{3311}[0]->{5850} == 1;
		}
	}

	return 0;
}

#get the timestamp, when the group was created
#you must pass the return code of getGroupInfo as the first argument
sub getGroupCreatedAt{
	return $_[0]->{9002};
}

#this returns the mood ids, that are configured for a certain group on the gateway
#it is an array, with one group id per element
#first arg: gateway address
#second arg: gateway secret
#third arg: group id
sub getMoods{
	return coapCommand($_[0], $_[1], 'GET', PATH_MOODS_ROOT . "/" . $_[2], {});
}

#get the JSON hash of a mood's path
#takes four arguments:
#first arg: gateway address
#second arg: gateway secret
#third arg: group address
#fourth arg: mood id
sub getMoodInfo{
	return coapCommand($_[0], $_[1], 'GET', PATH_MOODS_ROOT . "/" . $_[2] . "/" . $_[3], {});
}

#get the user defined name of the group
#you must pass the return code of getMoodInfo as the first argument
sub getMoodName{
	return $_[0]->{9001};
}

# The output of the path PATH_GROUP_ROOT/GROUP_ADDRESS looks like follows (for bulbs, that can not change color)
#$VAR1 = {
#          '9003' => 193768,						-> id
#          '9018' => {								-> "HS_ACCESSORY_LINK"
#                      '15002' => {
#                                   '9003' => [
#                                               65536,
#                                               65537,			-> sub-devices, contained in group
#                                               65538
#                                             ]
#                                 }
#                    },
#          '5851' => 0,								-> dimming value
#          '9039' => 199947,						-> mood id
#          '5850' => 1,								-> on/off
#          '9002' => 1492280898,					-> created at
#          '9001' => 'TRADFRI group'				-> name
#        };
#
#
# The output of the path PATH_DEVICE_ROOT/LAMP_ADDRESS looks like follows. (for bulbs, that can not change color temperature)
# We can just write single values to change the attributes

# $VAR1 = {
		  # '9020' => 1492322690,			-> last seen
		  # '9003' => 65537,				-> id
		  # '9054' => 0,					-> ota update state?
		  # '3311' => [
					  # {
						# '9003' => 0,		-> id?
						# '5850' => 0,		-> on/off
						# '5851' => 91		-> brightness (dimmer)
					  # }
					# ],
		  # '9019' => 1,								-> reachable state
		  # '3' => {
				   # '0' => 'IKEA of Sweden',			-> manufacturer	
				   # '2' => '',
				  # '3' => '1.1.1.0-5.7.2.0',			-> sw version
				   # '6' => 1,
				   # '1' => 'TRADFRI bulb E27 opal 1000lm'		-> product name
				 # },
		  # '9001' => 'Fenster Links',			-> user defined name
		  # '9002' => 1492280964,				-> created at
		  # '5750' => 2							-> type
		# };

# for bulbs, that change color:
#$VAR1 = { 
#          '9019' => 1, 											-> reachability state
#          '3' => { 
#                   '6' => 1, 
#                   '0' => 'IKEA of Sweden', 						-> manufacturer
#                   '3' => '1.1.1.1-5.7.2.0', 						-> software version
#                   '1' => 'TRADFRI bulb E14 WS opal 400lm', 		-> product name
#                   '2' => '' 
#                 }, 
#          '5750' => 2, 											-> type: bulb?, but no information about the type		
#          '3311' => [ 												-> light information
#                      { 
#                        '5850' => 1, 								-> on/ off
#                        '5710' => 24694, 							-> color_y (CIE1931 model, max 65535)
#                        '5707' => 0, 								
#                        '5851' => 7, 								-> dim value (brightness)
#                        '5711' => 0, 								
#                        '5709' => 24930, 							-> color_x (CIE1931 model, max 65535)
#                        '9003' => 0, 								-> instance id?
#                        '5708' => 0, 
#                        '5706' => 'f5faf6' 						-> rgb color code
#                      } 
#                    ], 
#          '9001' => 'TRADFRI bulb E14 WS opal 400lm', 				-> user defined name
#          '9002' => 1492802359, 									-> paired/ created at
#          '9020' => 1492863561, 									-> last seen				
#          '9003' => 65539, 										-> device id
#          '9054' => 0 												-> OTA update state
#        }; 

# Moods are defined per Group
# An array of the mood ids of the group can be accessed under PATH_MOODS_ROOT/GROUP_ADDRESS
#
# the individual mood info is accessed under PATH_MOODS_ROOT/GROUP_ADDRESS/MOOD_ID
# {
#    "9001":"FOCUS",												-> user name
#    "9002":1494088485,												-> created at?
#    "9003":206399,													-> mood id
#    "9057":2,														
#    "9068":1,														-> 1 means that mood is predefined by IKEA ?
#    "15013":[														-> configs for individual member devices
#       {
#          "5850":1,												-> on/ off
#          "5851":254,												-> dimvalue
#          "9003":65537												-> member id
#       },
#       {
#          "5850":1,
#          "5851":254,
#          "9003":65538
#       }
#    ]
# }

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

		coapCommand($_[0], $_[1], 'PUT', PATH_DEVICE_ROOT . "/$lampAddress", $command);
}

#set the dimming brightness of a lamp
#this requires four arguments: gateway address, gateway secret, the lamp address and the dimming value, between 0 and 254 (including these values)
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

		coapCommand($_[0], $_[1], 'PUT', PATH_DEVICE_ROOT . "/$lampAddress", $command);
}

#set the color of a lamp
#this requires five arguments:
#	- gateway address,
#	- gateway secret
#	- the lamp address,
#	- rgb color string, hexadecimal notation
#
# ikea uses the following combinations:
# F1E0B5 for standard
# F5FAF6 for cold
# EFD275 for warm
sub lampSetColorRGB{
	my $lampAddress = $_[2];
	my $rgb = $_[3];

	#caution: we need an hash reference here, so it must be defined with $
	my $command = {
			'3311' => [
					{
							'5706' => $rgb,
					}
			]
	};

	coapCommand($_[0], $_[1], 'PUT', PATH_DEVICE_ROOT . "/$lampAddress", $command);
}

#turn all devices in a group on or off
#this requires two arguments: the group address and the on/off state (as 0 or 1)
sub groupSetOnOff{
		my $groupAddress = $_[2];
		my $onOffState = $_[3];

		my $jsonState = $onOffState ? 1:0;

		my $command = {
			'5850' => $jsonState
		};

		coapCommand($_[0], $_[1], 'PUT', PATH_GROUP_ROOT . "/$groupAddress", $command);
}

#set the dimming brightness of all devices in agroup
#this requires two arguments: the group address and the dimming value, between 0 and 254 (including these values)
sub groupSetBrightness{
		my $groupAddress = $_[2];
		my $brightness = $_[3];

		if($brightness > 254){
				$brightness = 254;
		}
		if($brightness < 0){
				$brightness = 0;
		}

		#caution: we need an hash reference here, so it must be defined with $
		my $command = {
			'5851' => $brightness
		};

		coapCommand($_[0], $_[1], 'PUT', PATH_GROUP_ROOT . "/$groupAddress", $command);
}

#set a preconfigured mood for the group
#this requires two arguments: the group address and the mood id
sub groupSetMood{
		my $groupAddress = $_[2];
		my $moodID = $_[3];

		# @ToDo -> the group needs to be turned on, only setting the mood doesn't turn them on.
		# check, whether the IKEA App does it the same way (->wireshark capture)

		#caution: we need an hash reference here, so it must be defined with $
		my $command = {
			'9039' => $moodID,
			'5850' => 1,
		};

		coapCommand($_[0], $_[1], 'PUT', PATH_GROUP_ROOT . "/$groupAddress", $command);
}

1;