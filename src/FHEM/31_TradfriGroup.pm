# @author Peter Kappelt
# @version 1.16.dev-cf.4

package main;
use strict;
use warnings;

use Data::Dumper;
use JSON;

use constant{
	PATH_DEVICE_ROOT =>		'/15001',
	PATH_GROUP_ROOT =>		'/15004',
	PATH_MOODS_ROOT =>		'/15005',
};

my %TradfriGroup_gets = (
	'groupInfo'		=> ' ',
	'moods'			=> ' ',
);

my %TradfriGroup_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
	'mood'		=> '',
);

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

#this hash will be filled with known moods, in the form 'moodname' => mood-id
#@todo this needs to be stored in $hash
my %moodsKnown = ();

#subs, that define command to control a group
# cmdSet* functions will return a string, containing the last part of the CoAP path (like /15004/65537) and a string containing the JSON data that shall be written
# dataGetGroup* functions will return the respective data, they expect a decoded JSON hash with the group information

#get the command and the path to turn all devices in a group on or off
#this requires two arguments: the group address and the on/off state (as 0 or 1)
sub cmdSetGroupOnOff{
		my $groupAddress = $_[0];
		my $onOffState = $_[1];

		my $jsonState = $onOffState ? 1:0;

		my $command = {
			'5850' => $jsonState
		};

		my $jsonString = JSON->new->utf8->encode($command);

		return (PATH_GROUP_ROOT . "/$groupAddress", $jsonString);
}

#get the command and the path to set the brightness of all devices in agroup
#this requires two arguments: the group address and the dimming value, between 0 and 254 (including these values)
sub cmdSetGroupBrightness{
		my $groupAddress = $_[0];
		my $brightness = $_[1];

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

		my $jsonString = JSON->new->utf8->encode($command);

		return (PATH_GROUP_ROOT . "/$groupAddress", $jsonString);
}

#get the command and the path to set a preconfigured mood for the group
#this requires two arguments: the group address and the mood id
sub cmdSetGroupMood{
		my $groupAddress = $_[0];
		my $moodID = $_[1];

		# @ToDo -> the group needs to be turned on, only setting the mood doesn't turn them on.
		# check, whether the IKEA App does it the same way (->wireshark capture)

		#caution: we need an hash reference here, so it must be defined with $
		my $command = {
			'9039' => $moodID,
			'5850' => 1,
		};

		my $jsonString = JSON->new->utf8->encode($command);

		return (PATH_GROUP_ROOT . "/$groupAddress", $jsonString);
}

#get the user defined name of the group
#pass decoded JSON data of /15004/group-id
sub dataGetGroupName{
	return $_[0]->{9001};
}

#get the device IDs of all group members
#pass decoded JSON data of /15004/group-id
sub dataGetGroupMembers{
	return $_[0]->{9018}{15002}{9003};
}

#get the current dimming value of a group
#pass decoded JSON data of /15004/group-id 
sub dataGetGroupBrightness{
	return $_[0]->{5851};
}

#get the current on/off state of a group
#pass decoded JSON data of /15004/group-id 
sub dataGetGroupOnOff{
	return $_[0]->{5850};
}

#get the timestamp, when the group was created
#pass decoded JSON data of /15004/group-id 
sub dataGetGroupCreatedAt{
	return $_[0]->{9002};
}

#get the id of the mood that is currently active
#pass decoded JSON data of /15004/group-id 
sub dataGetGroupMood{
	return $_[0]->{9039};
}

#get the user defined name of a mood
#pass decoded JSON data of /15005/group-id/mood-id
sub dataGetMoodName{
	return $_[0]->{9001};
}

#write a path that needs to be observed to the Gateway's observe cache
#IOWrite isn't possible because it only works if the IODev is opened, but we need to write to the Gateway Device's cache even if it is closed
#@todo check if a IODev is assigned
sub StartObservation($$){
	my ($hash, $path) = @_;

	no strict "refs";
	&{$modules{$hash->{IODev}->{TYPE}}{StartObserveFn}}($hash->{IODev}, $path);
	use strict "refs";
}

sub TradfriGroup_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGroup_Define';
	$hash->{UndefFn}    = 'TradfriGroup_Undef';
	$hash->{SetFn}      = 'TradfriGroup_Set';
	$hash->{GetFn}      = 'TradfriGroup_Get';
	$hash->{AttrFn}     = 'TradfriGroup_Attr';
	$hash->{ReadFn}     = 'TradfriGroup_Read';
	$hash->{ParseFn}	= 'TradfriGroup_Parse';
	$hash->{ParseDeviceUpdateFn} = 'TradfriGroup_ParseDeviceUpdate';

	$hash->{Match} = '^observedUpdate\|coaps:\/\/[^\/]*\/15004';

	$hash->{AttrList} =
		"usePercentDimming:1,0 "
		. $readingFnAttributes;
}

sub TradfriGroup_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 3) {
		return "too few parameters: define <name> TradfriGroup <GroupAddress>";
	}
   
	$hash->{name}  = $param[0];
	$hash->{groupAddress} = $param[2];

	#reverse search, for Parse
	$modules{TradfriGroup}{defptr}{$hash->{groupAddress}} = $hash;

	AssignIoPort($hash);

	#start observing the coap resource, so the module will be informed about status updates
	StartObservation($hash, PATH_GROUP_ROOT . "/" . $hash->{groupAddress});

	#@todo shall the moods get updated here?
	TradfriGroup_Get($hash, $hash->{name}, 'moods');

	return undef;
}

sub TradfriGroup_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriGroup_ParseDeviceUpdate($$$){
	my ($hash, $hash_iodev, $path) = @_;

	#called once a device (no matter if it is a member of the groud) was updated. 
	#path is /15001/device-id

	#@todo check, if $hash_iodev fits to the iodev that this instance uses

	my ($deviceID) = ($path =~ /(?:\/15001\/)([0-9]*)/);

	#check if the id is a member of this group
	if(defined($deviceID) && grep(/^$deviceID$/, @{$hash->{helper}{memberDevices}})){
		my $brightnessTotal = 0;		#sum of all brightnesses
		my $brightnessOn = 0;			#sum of the brightnesses of the devices that are on
		my $onDeviceCount = 0;		#number of devices that are on
		my $deviceCount = 0;		#number of iterated devices

		#following behavior:
		#if all devices are off the brightness is the average of all set brightnesses (of the devices that are turned off)
		#if at least one device is one, the brightness ist the average of the brightnesses of the devices that are turned on

		#iterate through all devices that are member of this group and set the variables
		for(my $i = 0; $i < int(@{$hash->{helper}{memberDevices}}); $i++){
			my $memberDeviceID = $hash->{helper}{memberDevices}[$i];			#the id of the member device

			#skip if there is no record in cache
			if(!exists($hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"})){
				next;
			}

			#only handle if all of the following is true
			if(
				exists($hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"}->{'state'}) &&			#a state is defined for the member device
				($hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"}->{'state'} eq 'OK') &&		#the record is marked as OK
				exists($hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"}->{3311}[0]->{5850}) &&	#it has a record for on/off state (i.e. it isn't a dimmer)
				exists($hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"}->{3311}[0]->{5851})		#it has a record for brightness (i.e. it isn't a dimmer)
			){
				my $deviceJSONInfo = $hash->{IODev}->{helper}{observeCache}{"/15001/$memberDeviceID"};
				my $brightness = $deviceJSONInfo->{3311}[0]->{5851};
				my $onOff = $deviceJSONInfo->{3311}[0]->{5850};

				$onDeviceCount++ if($onOff);				#increment onDeviceCount when the device is on
				$brightnessOn += $brightness if($onOff);	#add the current brightness to brightnessOn when its on
				$brightnessTotal += $brightness;			#accumulate all brightnesses
				$deviceCount++;								#all valid devices
			}
		}

		my $state = $onDeviceCount > 0 ? 'on':'off';
		my $dimvalue = 0;
		$dimvalue = $brightnessTotal / $deviceCount if ($onDeviceCount == 0) && ($deviceCount > 0);
		$dimvalue = $brightnessOn / $onDeviceCount if($onDeviceCount > 0);

		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		readingsBeginUpdate($hash);
		readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
		readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
		readingsEndUpdate($hash, 1);
	}
}

sub TradfriGroup_Parse($$){
	my ($io_hash, $message) = @_;
	
	#the message contains 'observedUpdate|coapPath|data' -> split it by the pipe character
	my @parts = split('\|', $message);

	if(int(@parts) < 3){
		#expecting at least three parts
		return undef;
	}

	#$parts[1], the coapPath is build up like this: coaps://Ip-or-dns-of-gateway/15004/Id-of-group
	#extract the group id with the following regex:
	my ($temp, $msgGroupId) = ($parts[1] =~ /(^coap.?:\/\/[^\/]*\/15004\/)([0-9]*)/);

	#check if group with the id exists
	if(my $hash = $modules{TradfriGroup}{defptr}{$msgGroupId}) 
	{
		# the path returned "Not Found" -> unknown resource, but this message still suits for this group
		if($parts[2] eq "Not Found"){
			$hash->{STATE} = "NotFound";
			return $hash->{NAME};
		}

		#parse the JSON data
		my $jsonData = eval{ JSON->new->utf8->decode($parts[2]) };
		if($@){
			return $hash->{NAME}; #the string was probably not valid JSON
		}
		#Log(0, $parts[2]);
		my $createdAt = FmtDateTimeRFC1123(dataGetGroupCreatedAt($jsonData));
		my $name = dataGetGroupName($jsonData);
		my $memberArray = dataGetGroupMembers($jsonData);
		my $members = join(' ', @{$memberArray});
		my $mood = dataGetGroupMood($jsonData);
		#my $dimvalue = dataGetGroupBrightness($jsonData);
		#$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
		#my $state = dataGetGroupOnOff($jsonData) ? 'on':'off';

		readingsBeginUpdate($hash);
		readingsBulkUpdateIfChanged($hash, 'createdAt', $createdAt, 1);
		readingsBulkUpdateIfChanged($hash, 'name', $name, 1);
		readingsBulkUpdateIfChanged($hash, 'members', $members, 1);
		readingsBulkUpdateIfChanged($hash, 'mood', $mood, 1);
		#updated in a device-based algorithm
		#readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
		#readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
		readingsEndUpdate($hash, 1);

		$hash->{helper}{memberDevices} = [@{$memberArray}];
		
		#@todo -> not good, we restart observing here every time
		#make sure that we are observing each slave-device
		for(my $i = 0; $i < scalar(@{$memberArray}); $i++){
			StartObservation($hash, PATH_DEVICE_ROOT . "/" . ${$memberArray}[$i]);
		}

		#return the appropriate group's name
		return $hash->{NAME}; 
	}
	
	return undef;
}

sub TradfriGroup_Get($@) {
	my ($hash, @param) = @_;
	
	return '"get TradfriGroup" needs at least one argument' if (int(@param) < 2);
	
	my $name = shift @param;
	my $opt = shift @param;
	if(!$TradfriGroup_gets{$opt}) {
		my @cList = keys %TradfriGroup_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	if($opt eq 'groupInfo'){
		my $jsonText = IOWrite($hash, 'get', PATH_GROUP_ROOT . "/" . $hash->{groupAddress}, '');

		if(!defined($jsonText)){
			return "Error while fetching group info!";
		}
		
		#parse the JSON data
		my $jsonData = eval{ JSON->new->utf8->decode($jsonText) };
		if($@){
			return "Unknown JSON:\n" . $jsonText; #the string was probably not valid JSON
		}

		return Dumper($jsonData);
	}elsif($opt eq 'moods'){
		#Log(0, "update moods");
		my $jsonText = IOWrite($hash, 'get', PATH_MOODS_ROOT . "/" . $hash->{groupAddress}, '');

		if(!defined($jsonText)){
			return "Error while fetching moods!";
		}
		
		#parse the JSON data
		my $moodIDList = eval{ JSON->new->utf8->decode($jsonText) };
		if(($@) || (ref($moodIDList) ne 'ARRAY')){
			Log(0, "unkw json" . $jsonText);
			return "Unknown JSON:\n" . $jsonText; #the string was probably not valid JSON
		}

		my $returnUserString = "";
		my $returnReadingString = "";
		%moodsKnown = ();

		for(my $i = 0; $i < scalar(@{$moodIDList}); $i++){
			my $jsonMoodText = IOWrite($hash, 'get', PATH_MOODS_ROOT . "/" . $hash->{groupAddress} . "/" . ${$moodIDList}[$i], '');

			my $moodName = "UNKNOWN";

			if(defined($jsonMoodText)){
				#parse the JSON data
				my $moodInfo = eval{ JSON->new->utf8->decode($jsonMoodText) };
				if(!($@)){
					$moodName = dataGetMoodName($moodInfo);
				}
			}

			#remove whitespaces in mood names
			$moodName =~ s/\s//;

			$returnUserString .= "- " .
				${$moodIDList}[$i] .
				": " .
				$moodName . 
				"\n";

			$returnReadingString .= 	${$moodIDList}[$i] .
										"//" .
										$moodName .
										" ";

			$moodsKnown{"$moodName"} = int(${$moodIDList}[$i]);
		}

		readingsSingleUpdate($hash, 'moods', $returnReadingString, 1);

		return $returnUserString;
	}

	return $TradfriGroup_gets{$opt};
}

sub TradfriGroup_Set($@) {
	my ($hash, @param) = @_;
	
	return '"set TradfriGroup" needs at least one argument' if (int(@param) < 2);

	my $argcount = int(@param);
	
	my $name = shift @param;
	my $opt = shift @param;
	my $value = join("", @param);
	
	if(!defined($TradfriGroup_sets{$opt})) {
		my @cList = keys %TradfriGroup_sets;
		#return "Unknown argument $opt, choose one of " . join(" ", @cList);

		#dynamic option: max dimvalue
		my $dimvalueMax = 254;
		$dimvalueMax = 100 if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		#dynamic option: moods
		my $moodsList = join(",", map { "$_" } keys %moodsKnown);

		return "Unknown argument $opt, choose one of dimvalue:slider,0,1,$dimvalueMax off on mood:$moodsList";
	}
	
	$TradfriGroup_sets{$opt} = $value;

	if($opt eq "on"){
		#@todo state shouldn't be updated here?!
		$hash->{STATE} = 'on';
		
		my ($coapPath, $coapData) = cmdSetGroupOnOff($hash->{groupAddress}, 1);
		return IOWrite($hash, 'write', $coapPath, $coapData);
	}elsif($opt eq "off"){
		#@todo state shouldn't be updated here?!
		$hash->{STATE} = 'off';
		
		my ($coapPath, $coapData) = cmdSetGroupOnOff($hash->{groupAddress}, 0);
		return IOWrite($hash, 'write', $coapPath, $coapData);
	}elsif($opt eq "dimvalue"){
		return '"set TradfriGroup dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);

		my $dimvalue = int($value);
		$dimvalue = int($value * 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		my ($coapPath, $coapData) = cmdSetGroupBrightness($hash->{groupAddress}, $dimvalue);
		return IOWrite($hash, 'write', $coapPath, $coapData);
	}elsif($opt eq "mood"){
		return '"set TradfriGroup mood" requires a mood ID or a mood name. You can list the available moods for this group by running "get moods"'  if ($argcount < 3);

		if(!($value =~ /[1-9]+/)){
			#user wrote a string -> a mood name
			if(exists($moodsKnown{"$value"})){
				$value = $moodsKnown{"$value"};
			}else{
				#try to update the list of known moods -> maybe it is a new mood and the list isn't updated yet
				TradfriGroup_Get($hash, $hash->{name}, 'moods');
				if(exists($moodsKnown{"$value"})){
					$value = $moodsKnown{"$value"};
				}else{
					return "Unknown mood!";
				}
			}
		}

		my ($coapPath, $coapData) = cmdSetGroupMood($hash->{groupAddress}, $value);
		return IOWrite($hash, 'write', $coapPath, $coapData);
	}

	return undef;
}


sub TradfriGroup_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
		if($attr_name eq ""){

		}
	}
	return undef;
}

1;

=pod

=item device
=item summary controls an IKEA Trådfri lighting group
=item summary_DE steuert eine IKEA Trådfri Beleuchtungsgruppe

=begin html

<a name="TradfriGroup"></a>
<h3>TradfriGroup</h3>
<ul>
    <i>TradfriGroup</i> is a module for controlling an IKEA Trådfri lighting group. You currently need a gateway for the connection.
    See TradfriGateway.
    <br><br>
    <a name="TradfriGroupdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; TradfriGroup &lt;group-address&gt;</code>
        <br><br>
        Example: <code>define trGroupOne TradfriGroup 193768</code>
        <br><br>
        You can get the ID of the lighting groups by calling "get TradfriGW groupList" on the gateway device
    </ul>
    <br>
    
    <a name="TradfriGroupset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; [&lt;value&gt;]</code>
        <br><br>
        You can set the following options. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>on</i><br>
                  Turns all devices in the group on.<br>The brightness is the one, before the devices were turned off</li>
              <li><i>off</i><br>
                  Turn all devices in the group off.</li>
              <li><i>dimvalue</i><br>
                  Set the brightness of all devices in the group.<br>
                  You need to specify the brightness value as an integer between 0 and 100/254.<br>
                  The largest value depends on the attribute "usePercentDimming".<br>
                  If this attribute is set, the largest value will be 100.<br>
                  By default, it isn't set, so the largest value is 254.<br>
                  A brightness value of 0 turns the devices off.<br>
                  If the devices are off, and you set a value greater than 0, they'll turn on.</li>
              <li><i>mood</i><br>
                  Set the mood of the group.<br>
                  Moods are preconfigured color temperatures, brightnesses and states for each device of the group<br>
                  In order to set the mood, you need a mood ID or the mood's name.<br>
                  You can list the moods that are available for this group by running "get moods".<br>
                  Note, that the mood's name isn't necessarily the same that you've defined in the IKEA app.
                  This module is currently unable to handle whitespaces in mood names, so whitespaces get removed internally.
                  Check the reading "moods" after running "get moods" in order to get the names, that you may use with this module.<br>
                  Mood names are case-sensitive. Mood names, that are only made out of numbers are not supported.</li>
        </ul>
    </ul>
    <br>

    <a name="TradfriGroupget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can get the following information about the group. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
		<br><br>
        Options:
        <ul>
              <li><i>groupInfo</i><br>
                  The RAW JSON-formatted data, that was returned from the group info. Just for development and/ or additional info</li>
               <li><i>moods</i><br>
                  Get all moods (their name and their ID) that are configured for this group<br>
                  Please note, that the mood IDs may differ between different groups (though they are the same moods) -> check them for each group
                  Additionally, the reading "moods" is set to a list of available moods.</li>
        </ul>
    </ul>
    <br>
    
	<a name="TradfriGroupreadings"></a>
    <b>Readings</b><br>
    <ul>
        The following readings are displayed for a group. Once there is a change and the connection to the gateway is made, they get updated automatically.
		<br><br>
        Readings:
        <ul>
              <li><i>createdAt</i><br>
                  A timestamp string, like "Sat, 15 Apr 2017 18:29:24 GMT", that indicates, when the group was created in the gateway.</li>
              <li><i>dimvalue</i><br>
                  The brightness that is set for this group. It is a integer in the range of 0 to 100/ 254.<br>
                  The greatest dimvalue depends on the attribute "usePercentDimming", see below.</li>
              <li><i>members</i><br>
                  A space separated list of all device IDs that are member of this group.</li>
              <li><i>moods</i><br>
                  A space separated list of all moods and their names that are defined for the group, e.g.<br>
                  198884//EVERYDAY 213983//RELAX 206399//FOCUS<br>
                  This reading isn't updated automatically, you've to call "get moods" in order to refresh them.</li>    
              <li><i>name</i><br>
                  The name of the group that you've set in the app.</li>
              <li><i>state</i><br>
                  Indicates, whether the group is on or off. Thus, the reading's value is either "on" or "off", too.</li>
        </ul>
    </ul>
    <br>

    <a name="TradfriGroupattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i>usePercentDimming</i> 0/1<br>
            	If this attribute is one, the largest value for "set dimvalue" will be 100.<br>
            	Otherwise, the largest value is 254.<br>
            	This attribute is useful, if you need to control the brightness in percent (0-100%)<br>
            	For backward compatibility, it is disabled by default, so the largest dimvalue is 254 by default.
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut