# @author Peter Kappelt
# @version 1.13

package main;
use strict;
use warnings;

use Data::Dumper;

use TradfriLib;

my %TradfriGroup_gets = (
	'groupInfo'		=> ' ',
	'groupMembers' 	=> ' ',
	'dimvalue'		=> ' ',
	'state'			=> ' ',
	'name'			=> ' ',
	'createdAt'		=> ' ',
	'updateInfo'	=> ' ',
);

my %TradfriGroup_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
);

sub TradfriGroup_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGroup_Define';
	$hash->{UndefFn}    = 'TradfriGroup_Undef';
	$hash->{SetFn}      = 'TradfriGroup_Set';
	$hash->{GetFn}      = 'TradfriGroup_Get';
	$hash->{AttrFn}     = 'TradfriGroup_Attr';
	$hash->{ReadFn}     = 'TradfriGroup_Read';

	$hash->{Match} = ".*";

	$hash->{AttrList} =
		"autoUpdateInterval "
		. "usePercentDimming:1,0"
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

	AssignIoPort($hash);

	#my $autoUpdateInterval = AttrVal($hash->{name}, 'autoUpdateInterval', 0);
	#InternalTimer(gettimeofday()+$autoUpdateInterval, "TradfriGroup_GetUpdate", $hash) unless ($autoUpdateInterval == 0);

	return undef;
}

sub TradfriGroup_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
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

		if($jsonGroupInfo ~~ undef){
			return "Error while fetching group info!";
		}

		return(Dumper($jsonGroupInfo));
	}elsif($opt eq 'groupMembers'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if($jsonGroupInfo ~~ undef){
			return "Error while fetching group info!";
		}

		my $memberArray = TradfriLib::getGroupMembers($jsonGroupInfo);
		my $returnString = '';

		# prepare a humand readable list of the devices, containing device type, manufacturer and name
		for(my $i = 0; $i < scalar(@{$memberArray}); $i++){
			my $currentDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, ${$memberArray}[$i]);

			$returnString .= '- ' . ${$memberArray}[$i] . ': ';

			if($currentDeviceInfo ~~ undef){
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
		if($jsonGroupInfo ~~ undef){
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
		if($jsonGroupInfo ~~ undef){
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
		if($jsonGroupInfo ~~ undef){
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
		if($jsonGroupInfo ~~ undef){
			return "Error while fetching group info!";
		}

		my $createdAt = FmtDateTimeRFC1123(TradfriLib::getGroupCreatedAt($jsonGroupInfo));
		readingsSingleUpdate($hash, 'createdAt', $createdAt, 1);
		return $createdAt;
	}elsif($opt eq 'updateInfo'){
		#update the following readings: createdAt, state, name, dimvalue, groupMembers
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		if($jsonGroupInfo ~~ undef){
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
		my $dimvalueMax = 254;
		$dimvalueMax = 100 if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		return "Unknown argument $opt, choose one of dimvalue:slider,0,1,$dimvalueMax off on";
	}
	
	$hash->{STATE} = $TradfriGroup_sets{$opt} = $value;

	if($opt eq "on"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		TradfriLib::groupSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, 1);
		readingsSingleUpdate($hash, 'state', 'on', 1);
	}elsif($opt eq "off"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		TradfriLib::groupSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, 0);
		readingsSingleUpdate($hash, 'state', 'off', 1);
	}elsif($opt eq "dimvalue"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		return '"set TradfriGroup dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);

		my $dimvalue = int($value);
		$dimvalue = int($value * 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		TradfriLib::groupSetBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, $dimvalue);
		readingsSingleUpdate($hash, 'dimvalue', int($value), 1);
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
                  Additionally, the reading "createdAt" gets set to the resulting value.</li>
              <li><i>dimvalue</i><br>
                  Get the brightness value of the group<br>
                  If the member devices are set to different brightnesses, this will return the mean of the member brightnesses<br>
                  Additionally, the reading "dimvalue" gets set to the resulting value.</li>
              <li><i>groupInfo</i><br>
                  The RAW JSON-formatted data, that was returned from the group info. Just for development and/ or additional info</li>
        	  <li><i>groupMembers</i><br>
                  Returns a list of member device IDs, there name and type.<br>
                  Additionally, the reading "members" gets set to a space-seperated list of the member's device IDs</li>
              <li><i>name</i><br>
                  Get user defined name of the group<br>
                  Additionally, the reading "name" gets set to the resulting value.</li>
              <li><i>state</i><br>
                  Get the state (-> on/off) of the group<br>
                  It is "on", if at least one of the member devices is on<br>
                  Additionally, the reading "state" gets set to the resulting value.</li>
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