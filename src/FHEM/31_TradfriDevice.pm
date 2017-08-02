# @author Peter Kappelt
# @version 1.16.dev-cf.5

package main;
use strict;
use warnings;

use Data::Dumper;
use JSON;

my %TradfriDevice_gets = (
#	'deviceInfo'	=> ' ',
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
	$hash->{ParseFn}	= 'TradfriDevice_Parse';

	$hash->{Match} = '^subscribedDeviceUpdate::';

	$hash->{AttrList} =
		"usePercentDimming:1,0 "
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

	#reverse search, for Parse
	$modules{TradfriDevice}{defptr}{$hash->{deviceAddress}} = $hash;

	AssignIoPort($hash);

	#start observing the coap resource, so the module will be informed about status updates
	#@todo stop observing, when deleting module, or stopping FHEM
	IOWrite($hash, 0, 'subscribe', $hash->{deviceAddress});

	return undef;
}

sub TradfriDevice_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

#messages look like this: (without newlines)
# subscribedDeviceUpdate::device-id::{
#    "lastSeenAt":1501407261,
#    "createdAt":1492280964,
#    "reachabilityState":1,
#    "name":"Fenster Links",
#    "dimvalue":200,
#    "type":"TRADFRI bulb E27 opal 1000lm",
#    "deviceid":65537,
#    "version":"1.1.1.0-5.7.2.0",
#    "manufacturer":"IKEA of Sweden",
#    "onoff":0
# }
sub TradfriDevice_Parse ($$){
	my ($io_hash, $message) = @_;

	my @parts = split('::', $message);

	if(int(@parts) < 3){
		#expecting at least three parts
		return undef;
	}
	
	#parse the JSON data
	my $jsonData = eval{ JSON->new->utf8->decode($parts[2]) };
	if($@){
		return undef; #the string was probably not valid JSON
	}

	my $messageDeviceID = $parts[1];

	#check if device with the id exists
	if(my $hash = $modules{TradfriDevice}{defptr}{$messageDeviceID}) 
	{
		my $manufacturer = $jsonData->{'manufacturer'} || '';
		my $type = $jsonData->{'type'} || '';
		my $dimvalue = $jsonData->{'dimvalue'} || '0';
		$dimvalue = int($dimvalue / 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
		my $state = ($jsonData->{'onoff'} || '0') ? 'on':'off';
		my $name = $jsonData->{'name'} || '';
		my $createdAt = FmtDateTimeRFC1123($jsonData->{'createdAt'} || '');
		my $reachableState = $jsonData->{'reachabilityState'} || '';
		my $lastSeen = FmtDateTimeRFC1123($jsonData->{'lastSeenAt'} || '');
		my $color = $jsonData->{'color'} || '';
		my $version = $jsonData->{'version'} || '';

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
		
		#return the appropriate device's name
		return $hash->{NAME}; 
	}
	
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
		# my $jsonText = IOWrite($hash, 'get', PATH_DEVICE_ROOT . "/" . $hash->{deviceAddress}, '');

		# if(!defined($jsonText)){
		# 	return "Error while fetching device info!";
		# }
		
		# #parse the JSON data
		# my $jsonData = eval{ JSON->new->utf8->decode($jsonText) };
		# if($@){
		# 	return $jsonText; #the string was probably not valid JSON
		# }

		# return Dumper($jsonData);
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
		#@todo state shouldn't be updated here?!
		$hash->{STATE} = 'on';

		return IOWrite($hash, 0, 'set', $hash->{deviceAddress}, 'onoff::1');
	}elsif($opt eq "off"){
		#@todo state shouldn't be updated here?!
		$hash->{STATE} = 'off';

		return IOWrite($hash, 0, 'set', $hash->{deviceAddress}, 'onoff::0');
	}elsif($opt eq "dimvalue"){
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);
		
		my $dimvalue = int($value);
		$dimvalue = int($value * 2.54 + 0.5) if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);

		return IOWrite($hash, 0, 'set', $hash->{deviceAddress}, "dimvalue::$dimvalue");
	}elsif($opt eq "color"){
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
	
		return IOWrite($hash, 0, 'set', $hash->{deviceAddress}, "color::$rgb");
	}

	return undef;
}


sub TradfriDevice_Attr(@) {
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
                  You may pass "warm", "cold", "standard" or a RGB code in the format "RRGGBB"<br>
                  Any RGB code can be set, though the bulb only is able to switch to certain colors.<br>
                  IKEA uses the following RGB codes for their colors. Bulbs I've tested could only be set to those.<br>
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
              <li><i>deviceInfo</i><br>
                  The RAW JSON-formatted data, that was returned from the device info. Just for development and/ or additional info</li>
        </ul>
    </ul>
    <br>

    <a name="TradfriDevicereadings"></a>
    <b>Readings</b><br>
    <ul>
        The following readings are displayed for a device. Once there is a change and the connection to the gateway is made, they get updated automatically.
		<br><br>
        Readings:
        <ul>
              <li><i>color</i><br>
                  The color that is set for this bulb. Its value is a hexadecimal code in the format "RRGGBB".<br>
                  If the device doesn't support the change of colors the reading's value will be "0"</li>
              <li><i>createdAt</i><br>
                  A timestamp string, like "Sat, 15 Apr 2017 18:29:24 GMT", that indicates, when the device was paired with the gateway.</li>
              <li><i>dimvalue</i><br>
                  The brightness that is set for this device. It is a integer in the range of 0 to 100/ 254.<br>
                  The greatest dimvalue depends on the attribute "usePercentDimming", see below.</li>
              <li><i>lastSeen</i><br>
                  A timestamp string, like "Wed, 12 Jul 2017 14:32:06 GMT". I haven't understand the mechanism behind it yet.<br>
                  Communication with the device won't update the lastSeen-timestamp - so I don't get the point of it. This needs some more investigation.</li>
              <li><i>manufacturer</i><br>
                  The device's manufacturer. Since there are only devices from IKEA available yet, it'll surely be "IKEA of Sweden".</li>
              <li><i>name</i><br>
                  The name of the device that you've set in the app.</li>
              <li><i>reachableState</i><br>
                  Indicates whether the gateway is able to connect to the device. This reading's value is either "0" or "1", where "1" indicates reachability.</li>
              <li><i>softwareVersion</i><br>
                  The version of the software that is running on the device.</li>
              <li><i>state</i><br>
                  Indicates, whether the device is on or off. Thus, the reading's value is either "on" or "off", too.</li>
              <li><i>type</i><br>
                  The product type of the device. Is a string like "TRADFRI bulb E27 opal 1000lm"</li>
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