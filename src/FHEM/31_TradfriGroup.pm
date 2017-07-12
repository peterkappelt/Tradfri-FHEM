# @author Peter Kappelt
# @version 1.16.dev-cf.1

package main;
use strict;
use warnings;

use Data::Dumper;

use TradfriLib;

use constant{
	PATH_GROUP_ROOT =>		'/15004',
	PATH_MOODS_ROOT =>		'/15005',
};

my %TradfriGroup_gets = (
	'groupInfo'		=> ' ',
	'groupMembers' 	=> ' ',
	'dimvalue'		=> ' ',
	'state'			=> ' ',
	'name'			=> ' ',
	'moods'			=> ' ',
	'createdAt'		=> ' ',
	'updateInfo'	=> ' ',
);

my %TradfriGroup_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
	'mood'		=> '',
);

#this hash will be filled with known moods, in the form 'moodname' => mood-id
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
#pass decoded JSON data of /15001/group-id
sub dataGetGroupMembers{
	return $_[0]->{9018}{15002}{9003};
}

#get the current dimming value of a group
#pass decoded JSON data of /15001/group-id 
sub dataGetGroupBrightness{
	return $_[0]->{5851};
}

#get the current on/off state of a group
#pass decoded JSON data of /15001/group-id 
sub dataGetGroupOnOff{
	return $_[0]->{5850};
}

#get the timestamp, when the group was created
#pass decoded JSON data of /15001/group-id 
sub dataGetGroupCreatedAt{
	return $_[0]->{9002};
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

	$hash->{Match} = '^observedUpdate\|coaps:\/\/[^\/]*\/15004';

	$hash->{AttrList} =
		"autoUpdateInterval "
		. "usePercentDimming:1,0 "
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
	IOWrite($hash, 'observeStart', PATH_GROUP_ROOT . "/" . $hash->{groupAddress}, '');

	TradfriGroup_Get($hash, $hash->{name}, 'moods');

	return undef;
}

sub TradfriGroup_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriGroup_Parse($$){
	my ($io_hash, $message) = @_;
	
	#the message contains 'coapObserveStart|coapPath|data' -> split it by the pipe character
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
			return undef; #the string was probably not valid JSON
		}

		my $createdAt = FmtDateTimeRFC1123(dataGetGroupCreatedAt($jsonData));
		my $name = dataGetGroupName($jsonData);
		my $memberArray = dataGetGroupMembers($jsonData);
		my $members = join(' ', @{$memberArray});
		my $dimvalue = dataGetGroupBrightness($jsonData);
		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
		my $state = dataGetGroupOnOff($jsonData) ? 'on':'off';

		readingsBeginUpdate($hash);
		readingsBulkUpdateIfChanged($hash, 'createdAt', $createdAt, 1);
		readingsBulkUpdateIfChanged($hash, 'name', $name, 1);
		readingsBulkUpdateIfChanged($hash, 'members', $members, 1);
		readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
		readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
		readingsEndUpdate($hash, 1);
		
		#return the appropriate group's name
		return $hash->{NAME}; 
	}
	
	return undef;
}

sub TradfriGroup_GetUpdate($@){
	my ($hash) = @_;

	if(AttrVal($hash->{name}, 'autoUpdateInterval', 0) != 0){
		TradfriGroup_Get($hash, $hash->{name}, 'updateInfo');

		InternalTimer(gettimeofday()+AttrVal($hash->{name}, 'autoUpdateInterval', 30), "TradfriGroup_GetUpdate", $hash);
	}
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
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});

		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		return(Dumper($jsonGroupInfo));
	}elsif($opt eq 'groupMembers'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $memberArray = TradfriLib::getGroupMembers($jsonGroupInfo);
		my $returnString = '';

		# prepare a humand readable list of the devices, containing device type, manufacturer and name
		for(my $i = 0; $i < scalar(@{$memberArray}); $i++){
			my $currentDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, ${$memberArray}[$i]);

			$returnString .= '- ' . ${$memberArray}[$i] . ': ';

			if(!defined($currentDeviceInfo)){
				$returnString .= 'Unknown';
			}else{
				$returnString .= TradfriLib::getDeviceManufacturer($currentDeviceInfo) .
					" " .
					TradfriLib::getDeviceType($currentDeviceInfo) .
					" (" .
					TradfriLib::getDeviceName($currentDeviceInfo) .
					")";
			}

			$returnString .= "\n";
		}

		#update the reading with a list of the device IDs, space seperated
		readingsSingleUpdate($hash, 'members', join(' ', @{$memberArray}), 1);

		return $returnString;
	}elsif($opt eq 'dimvalue'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $dimvalue = TradfriLib::getGroupBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $jsonGroupInfo);

		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		readingsSingleUpdate($hash, 'dimvalue', $dimvalue, 1);
		return $dimvalue;
	}elsif($opt eq 'state'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $state = TradfriLib::getGroupOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $jsonGroupInfo) ? 'on':'off';
		readingsSingleUpdate($hash, 'state', $state, 1);
		return $state;
	}elsif($opt eq 'name'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $name = TradfriLib::getGroupName($jsonGroupInfo);
		readingsSingleUpdate($hash, 'name', $name, 1);
		return $name;
	}elsif($opt eq 'createdAt'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $createdAt = FmtDateTimeRFC1123(TradfriLib::getGroupCreatedAt($jsonGroupInfo));
		readingsSingleUpdate($hash, 'createdAt', $createdAt, 1);
		return $createdAt;
	}elsif($opt eq 'moods'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $moodIDList = TradfriLib::getMoods($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});

		if(!defined($moodIDList)){
			return "Error while fetching moods!";
		}

		my $returnUserString = "";
		my $returnReadingString = "";
		%moodsKnown = ();

		for(my $i = 0; $i < scalar(@{$moodIDList}); $i++){
			my $moodInfo = TradfriLib::getMoodInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, ${$moodIDList}[$i]);

			#remove whitespaces in mood names
			my $moodName = TradfriLib::getMoodName($moodInfo);
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
	}elsif($opt eq 'updateInfo'){
		#update the following readings: createdAt, state, name, dimvalue, groupMembers
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if(!defined($jsonGroupInfo)){
			return "Error while fetching group info!";
		}

		my $createdAt = FmtDateTimeRFC1123(TradfriLib::getGroupCreatedAt($jsonGroupInfo));
		my $name = TradfriLib::getGroupName($jsonGroupInfo);
		my $memberArray = TradfriLib::getGroupMembers($jsonGroupInfo);
		my $members = join(' ', @{$memberArray});
		my $dimvalue = TradfriLib::getGroupBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $jsonGroupInfo);
		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
		my $state = TradfriLib::getGroupOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $jsonGroupInfo) ? 'on':'off';

		readingsBeginUpdate($hash);
		readingsBulkUpdateIfChanged($hash, 'createdAt', $createdAt, 1);
		readingsBulkUpdateIfChanged($hash, 'name', $name, 1);
		readingsBulkUpdateIfChanged($hash, 'members', $members, 1);
		readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
		readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
		readingsEndUpdate($hash, 1);
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

	#return "$opt set to $value.";
}


sub TradfriGroup_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
		if($attr_name eq "autoUpdateInterval"){
			if($attr_value eq ''){
				return "You need to specify the interval!";
			}
			if($attr_value ne 0){
				my $hash = $defs{$name};

				InternalTimer(gettimeofday()+AttrVal($hash->{name}, 'autoUpdateInterval', 30), "TradfriGroup_GetUpdate", $hash);
			}
#		}elsif($attr_name eq "gatewaySecret"){
#			if($attr_value ne ''){
#			}else{
#				return "You need to specify a gateway secret!";
#			}
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
              <li><i>createdAt</i><br>
                  Get the date and the time, when the group was created.<br>
                  Additionally, the reading "createdAt" is set to the resulting value.</li>
              <li><i>dimvalue</i><br>
                  Get the brightness value of the group<br>
                  If the member devices are set to different brightnesses, this will return the mean of the member brightnesses<br>
                  Additionally, the reading "dimvalue" is set to the resulting value.</li>
              <li><i>groupInfo</i><br>
                  The RAW JSON-formatted data, that was returned from the group info. Just for development and/ or additional info</li>
        	  <li><i>groupMembers</i><br>
                  Returns a list of member device IDs, there name and type.<br>
                  Additionally, the reading "members" is set to a space-seperated list of the member's device IDs</li>
               <li><i>moods</i><br>
                  Get all moods (their name and their ID) that are configured for this group<br>
                  Please note, that the mood IDs may differ between different groups (though they are the same moods) -> check them for each group
                  Additionally, the reading "moods" is set to a list of available moods.</li>
              <li><i>name</i><br>
                  Get user defined name of the group<br>
                  Additionally, the reading "name" is set to the resulting value.</li>
              <li><i>state</i><br>
                  Get the state (-> on/off) of the group<br>
                  It is "on", if at least one of the member devices is on<br>
                  Additionally, the reading "state" is set to the resulting value.</li>
              <li><i>updateInfo</i><br>
                  Update the readings createdAt, dimvalue, members, name and state according to the above described values.</li>
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
            <li><i>autoUpdateInterval</i> <time-seconds><br>
            	If this value is not 0 or undefined, the readings createdAt, dimvalue, members, name and state will be updated automatically.<br>
            	The value is the duration between the updates, in seconds.
            </li>
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