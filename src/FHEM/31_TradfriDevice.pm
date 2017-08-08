# @author Peter Kappelt
# @version 1.17

package main;
use strict;
use warnings;

use Data::Dumper;

use TradfriLib;

my %TradfriDevice_gets = (
	'deviceInfo'	=> ' ',
	'type'			=> ' ',
	'manufacturer'	=> ' ',
	'dimvalue'		=> ' ',
	'state'			=> ' ',
	'name'			=> ' ',
	'createdAt'		=> ' ',
	'reachableState'=> ' ',
	'lastSeen'		=> ' ',
	'color'			=> ' ',
	'softwareVersion' => ' ',
	'updateInfo'	=> ' ',
);

my %TradfriDevice_sets = (
	'on'		=> '',
	'off'		=> '',	
	'dimvalue'	=> '',
	'color'		=> '',
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

	$hash->{AttrList} =
		"autoUpdateInterval "
		. "usePercentDimming:1,0 "
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

	AssignIoPort($hash);

	return undef;
}

sub TradfriDevice_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriDevice_GetUpdate($@){
	my ($hash) = @_;

	if(AttrVal($hash->{name}, 'autoUpdateInterval', 0) != 0){
		TradfriDevice_Get($hash, $hash->{name}, 'updateInfo');

		InternalTimer(gettimeofday()+AttrVal($hash->{name}, 'autoUpdateInterval', 30), "TradfriDevice_GetUpdate", $hash);
	}
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
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		return(Dumper($jsonDeviceInfo));
	}elsif($opt eq 'manufacturer'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $manufacturer = TradfriLib::getDeviceManufacturer($jsonDeviceInfo);

		readingsSingleUpdate($hash, 'manufacturer', $manufacturer, 1);
		return($manufacturer);
	}elsif($opt eq 'type'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $type = TradfriLib::getDeviceType($jsonDeviceInfo);

		readingsSingleUpdate($hash, 'type', $type, 1);
		return($type);
	}elsif($opt eq 'dimvalue'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $dimvalue = TradfriLib::getDeviceBrightness($jsonDeviceInfo);

		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		readingsSingleUpdate($hash, 'dimvalue', $dimvalue, 1);
		return($dimvalue);
	}elsif($opt eq 'state'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $state = TradfriLib::getDeviceOnOff($jsonDeviceInfo) ? 'on':'off';

		readingsSingleUpdate($hash, 'state', $state, 1);
		return($state);
	}elsif($opt eq 'name'){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $name = TradfriLib::getDeviceName($jsonDeviceInfo);

		readingsSingleUpdate($hash, 'name', $name, 1);
		return($name);
	}elsif($opt eq 'createdAt'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $createdAt = FmtDateTimeRFC1123(TradfriLib::getDeviceCreatedAt($jsonDeviceInfo));
		readingsSingleUpdate($hash, 'createdAt', $createdAt, 1);
		return $createdAt;
	}elsif($opt eq 'softwareVersion'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $version = TradfriLib::getDeviceSoftwareVersion($jsonDeviceInfo);
		readingsSingleUpdate($hash, 'softwareVersion', $version, 1);
		return $version;
	}elsif($opt eq 'reachableState'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $reachable = TradfriLib::getDeviceReachableState($jsonDeviceInfo);
		readingsSingleUpdate($hash, 'reachableState', $reachable, 1);
		return $reachable;
	}elsif($opt eq 'lastSeen'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $lastSeen = FmtDateTimeRFC1123(TradfriLib::getDeviceLastSeen($jsonDeviceInfo));
		readingsSingleUpdate($hash, 'lastSeen', $lastSeen, 1);
		return $lastSeen;
	}elsif($opt eq 'color'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $color = TradfriLib::getDeviceColor($jsonDeviceInfo);
		readingsSingleUpdate($hash, 'color', $color, 1);
		return $color;
	}elsif($opt eq 'updateInfo'){
		#check, whether we can connect to the gateway
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		my $jsonDeviceInfo = TradfriLib::getDeviceInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress});
		if(!defined($jsonDeviceInfo)){
			return "Error while fetching device info!";
		}

		my $manufacturer = TradfriLib::getDeviceManufacturer($jsonDeviceInfo);
		my $type = TradfriLib::getDeviceType($jsonDeviceInfo);
		my $dimvalue = TradfriLib::getDeviceBrightness($jsonDeviceInfo);
		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
		my $state = TradfriLib::getDeviceOnOff($jsonDeviceInfo) ? 'on':'off';
		my $name = TradfriLib::getDeviceName($jsonDeviceInfo);
		my $createdAt = FmtDateTimeRFC1123(TradfriLib::getDeviceCreatedAt($jsonDeviceInfo));
		my $reachableState = TradfriLib::getDeviceReachableState($jsonDeviceInfo);
		my $lastSeen = FmtDateTimeRFC1123(TradfriLib::getDeviceLastSeen($jsonDeviceInfo));
		my $color = TradfriLib::getDeviceColor($jsonDeviceInfo);
		my $version = TradfriLib::getDeviceSoftwareVersion($jsonDeviceInfo);

		readingsBeginUpdate($hash);
		readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
		readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
		readingsBulkUpdateIfChanged($hash, 'name', $name, 1);
		readingsBulkUpdateIfChanged($hash, 'createdAt', $createdAt, 1);
		readingsBulkUpdateIfChanged($hash, 'softwareVersion', $version, 1);
		readingsBulkUpdateIfChanged($hash, 'type', $type, 1);
		readingsBulkUpdateIfChanged($hash, 'manufacturer', $manufacturer, 1);
		readingsBulkUpdateIfChanged($hash, 'reachableState', $reachableState, 1);
		readingsBulkUpdateIfChanged($hash, 'color', $color, 1);
		readingsBulkUpdateIfChanged($hash, 'lastSeen', $lastSeen, 1);
		readingsEndUpdate($hash, 1);	
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
		#return "Unknown argument $opt, choose one of " . join(" ", @cList);
		my $dimvalueMax = 254;
		$dimvalueMax = 100 if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		return "Unknown argument $opt, choose one of on off dimvalue:slider,0,1,$dimvalueMax color:warm,cold,standard";
	}
	
	$TradfriDevice_sets{$opt} = $value;

	if($opt eq "on"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		$hash->{STATE} = 'on';
		TradfriLib::lampSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, 1);
		readingsSingleUpdate($hash, 'state', 'on', 1);
	}elsif($opt eq "off"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		$hash->{STATE} = 'off';
		TradfriLib::lampSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, 0);
		readingsSingleUpdate($hash, 'state', 'off', 1);
	}elsif($opt eq "dimvalue"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);
		
		my $dimvalue = int($value);
		$dimvalue = int($value * 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);


		TradfriLib::lampSetBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, $dimvalue);
		readingsSingleUpdate($hash, 'dimvalue', int($value), 1);
	}elsif($opt eq "color"){
		if(!$hash->{IODev}{canConnect}){
			return "The gateway device does not allow to connect to the gateway!\nThat usually means, that the software \"coap-client\" isn't found/ executable.\nCheck that and run \"get coapClientVersion\" on the gateway device!";
		}

		return '"set TradfriDevice color" requires RGB value in format "RRGGBB" or "warm", "cold", "standard"!'  if ($argcount < 3);
		
		my $rgb;

		if($value eq "warm"){
			$rgb = 'EFD275';
		}elsif($value eq "cold"){
			$rgb = 'F5FAF6';
		}elsif($value eq "standard"){
			$rgb = 'F1E0B5';
		}else{
			$rgb = $value;
		}
		
		TradfriLib::lampSetColorRGB($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{deviceAddress}, $rgb);
		readingsSingleUpdate($hash, 'color', $rgb, 1);
	}

	return undef;

	#return "$opt set to $value.";
}


sub TradfriDevice_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
		if($attr_name eq "autoUpdateInterval"){
			if($attr_value eq ''){
				return "You need to specify the interval!";
			}
			if($attr_value ne 0){
				my $hash = $defs{$name};

				InternalTimer(gettimeofday()+AttrVal($hash->{name}, 'autoUpdateInterval', 30), "TradfriDevice_GetUpdate", $hash);
			}
		}
	}
	return undef;
}

1;

=pod

=item device
=item summary controls an IKEA Trådfri device (bulb, panel)
=item summary_DE steuert ein IKEA Trådfri Gerät

=begin html

<a name="TradfriDevice"></a>
<h3>TradfriDevice</h3>
<ul>
    <i>TradfriDevice</i> is a module for controlling a single IKEA Trådfri device. You currently need a gateway for the connection.
    See TradfriGateway.
    <br><br>
    <a name="TradfriDevicedefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; TradfriDevice &lt;device-address&gt;</code>
        <br><br>
        Example: <code>define trDeviceOne TradfriDevice 65538</code>
        <br><br>
        You can get the ID of the devices by calling "get TradfriGW deviceList" on the gateway device
    </ul>
    <br>
    
    <a name="TradfriDeviceset"></a>
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
                  Turns the device on.<br>The brightness is the one, before the device was turned off</li>
              <li><i>off</i><br>
                  Turn the device off.</li>
              <li><i>dimvalue</i><br>
                  Set the brightness of the device.<br>
                  You need to specify the brightness value as an integer between 0 and 100/254.<br>
                  The largest value depends on the attribute "usePercentDimming".<br>
                  If this attribute is set, the largest value will be 100.<br>
                  By default, it isn't set, so the largest value is 254.<br>
                  A brightness value of 0 turns the device off.<br>
                  If the device is off, and you set a value greater than 0, it will turn on.</li>
              <li><i>color</i>
                  Set the color temperature of a bubl<br>
                  Of course, that only works with bulbs, that can change their color temperature<br>
                  You may pass "warm", "cold", "standard" or a RGB code in the format "RRGGBB" (though you can't use all RGB codes)<br>
                  IKEA uses the following RGB codes for their colors:<br>
				  <ul>
					<li>F1E0B5 for standard</li>
					<li>F5FAF6 for cold</li>
					<li>EFD275 for warm</li>
				  </ul>
				  Other RGB codes than listed here do not work with the current bulb (they only set their color to those three values).
                  </li>
        </ul>
    </ul>
    <br>

    <a name="TradfriDeviceget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can get the following information about the device. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
		<br><br>
        Options:
        <ul>
              <li><i>createdAt</i><br>
                  Get the date and the time, when the device was paired.<br>
                  Additionally, the reading "createdAt" gets set to the resulting value.</li>
              <li><i>deviceInfo</i><br>
                  The RAW JSON-formatted data, that was returned from the device info. Just for development and/ or additional info</li>
              <li><i>dimvalue</i><br>
                  Get the brightness value of the device<br>
                  Additionally, the reading "dimvalue" gets set to the resulting value.</li>
              <li><i>manufacturer</i><br>
                  Get the manufacturer of the device<br>
                  Additionally, the reading "manufacturer" gets set to the resulting value.<br>
                  For IKEA devices, this is "IKEA of Sweden".</li>
              <li><i>name</i><br>
                  Get user defined name of the device<br>
                  Additionally, the reading "name" gets set to the resulting value.</li>
              <li><i>softwareVersion</i><br>
                  Get user software version of the device<br>
                  Additionally, the reading "softwareVersion" gets set to the resulting value.</li>
              <li><i>state</i><br>
                  Get the state (-> on/off) of the device<br>
                  Additionally, the reading "state" gets set to the resulting value.</li>
              <li><i>reachableState</i><br>
                  Get, whether the device is reported as reachable by the gateway.<br>
                  Additionally, the reading "reachableState" gets set to the resulting value.</li>
              <li><i>lastSeen</i><br>
                  Get a timestamp, when the device was last seen by the gateay.<br>
                  However, this value seems to be somehow senseless. In my case, the devices were last seen about three hours ago - though I've just set/ read their values<br>
                  Futher investigation of this value is required<br>
                  Additionally, the reading "lastSeen" gets set to the resulting value.</li>
              <li><i>color</i><br>
                  Get the RGB color code that the bulb is set to, in format rrggbb.<br>
                  If the device doesn't support to change the color, this will return 0<br>
                  IKEA uses the following RGB codes for their colors:<br>
                  <ul>
					<li>F1E0B5 for standard</li>
					<li>F5FAF6 for cold</li>
					<li>EFD275 for warm</li>
				  </ul>
                  Additionally, the reading "color" gets set to the resulting value.</li>
              <li><i>type</i><br>
                  Get the type of the device<br>
                  Additionally, the reading "type" gets set to the resulting value.<br>
                  I've had the following types for development:
					<ul>
						<li>TRADFRI bulb E27 opal 1000lm</li>
						<li>TRADFRI bulb E14 WS opal 400lm</li>
					</ul>
                  </li>
              <li><i>updateInfo</i><br>
                  Update the readings color, createdAt, dimvalue, manufacturer, name, softwareVersion, state, reachableState, lastSeen and type according to the above described values.</li>
        </ul>
    </ul>
    <br>
    
    <a name="TradfriDeviceattr"></a>
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
            	If this value is not 0 or undefined, the readings readings color, createdAt, dimvalue, manufacturer, name, softwareVersion, state, reachableState, lastSeen and type will be updated automatically.<br>
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