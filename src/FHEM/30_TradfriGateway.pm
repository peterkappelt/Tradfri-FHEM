# @author Peter Kappelt
# @version 1.16.dev-cf.4

package main;
use strict;
use warnings;

use IO::Select;

require 'DevIo.pm';

use constant{
	PATH_DEVICE_ROOT =>		'/15001',
	PATH_GROUP_ROOT =>		'/15004',
	PATH_MOODS_ROOT =>		'/15005',
};

my %TradfriGateway_sets = (
#	'reopen'	=> ' ',
);

my %TradfriGateway_gets = (
	'deviceList'	=> ' ',
	'groupList'		=> ' ',
);

sub TradfriGateway_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGateway_Define';
	$hash->{UndefFn}    = 'TradfriGateway_Undef';
	$hash->{SetFn}      = 'TradfriGateway_Set';
	$hash->{GetFn}      = 'TradfriGateway_Get';
	$hash->{AttrFn}     = 'TradfriGateway_Attr';
	$hash->{ReadFn}     = 'TradfriGateway_Read';
	$hash->{WriteFn}	= 'TradfriGateway_Write';
	$hash->{ReadyFn}	= 'TradfriGateway_Ready';

	#custom function for logical devices to register themselves in the observe cache of the gateway
	#IOWrite is not possible, it only works if the connection is opened
	$hash->{StartObserveFn} = 'TradfriGateway_StartObserve';

	$hash->{Clients}	= "TradfriDevice:TradfriGroup";
	$hash->{MatchList} = {
			"1:TradfriDevice" => '^observedUpdate\|coaps:\/\/[^\/]*\/15001',
			"2:TradfriGroup" => '^observedUpdate\|coaps:\/\/[^\/]*\/15004' ,
			};
}

sub TradfriGateway_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 4) {
		return "too few parameters: define <name> TradfriGateway <gateway-ip> <gateway-secret>";
	}

	#close connection to socket, if open
	DevIo_CloseDev($hash);
	
	$hash->{name}  = $param[0];

	$hash->{gatewayAddress} = $param[2];
	$hash->{gatewaySecret} = $param[3];

	# @todo make user settable
	$hash->{DeviceName} = "localhost:1505";

	# all paths that are observed and their last received value
	$hash->{helper}{observeCache} = ();

	if(int(@param) > 4){
		#there was a fifth parameter
		#it is the path to the coap client, add it to the environments path
		#Edit: it is obsolete now! Give advice to the user
		Log(0, "[TradfriGateway] The parameter \"coap-client-directory\" in the gateway's definition is obsolete now! Please remove it as soon as possible!")
	}

	#open the socket connection
	#@todo react to return code
	my $ret = DevIo_OpenDev($hash, 0, "TradfriGateway_DeviceInit");

	return undef;
}

sub TradfriGateway_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriGateway_DeviceInit($){
	my $hash = shift;

	#set the PSK
	DevIo_SimpleWrite($hash, "setPSK|" . $hash->{gatewaySecret} . "\n", 2, 0);

	#start to observe all necessary resources
	TradfriGateway_StartObserveAll($hash);

	#init the data of all member groups
	#perform a get
	#@todo blocking call
	foreach my $groupID ( keys %{$modules{TradfriGroup}{defptr}}){
		my $groupData = TradfriGateway_Write($hash, 'get', '/15004/' . $groupID . '/', '');

		#remove any left whitespace
		$groupData =~ s/\r//g;
		$groupData =~ s/\n//g;

		#dispatch, like for a observe update
		Dispatch($hash, 'observedUpdate|coaps://gw/15004/' . $groupID . '|' . $groupData, undef);

		#start a mood update for the group
		no strict "refs";
		&{$modules{TradfriGroup}{GetFn}}($modules{TradfriGroup}{defptr}{$groupID}, $modules{TradfriGroup}{defptr}{$groupID}->{name}, 'moods');
		use strict "refs";
	}
}

#start to observe a specified path and handle the caching of the observed paths
sub TradfriGateway_StartObserve($$){
	my ( $hash, $path ) = @_;

	#put the path to the "observeCache" -> if the connection dies, the coapObserveStart command needs to be called again.
	if(!exists($hash->{helper}{observeCache}{"$path"})){
		$hash->{helper}{observeCache}{"$path"} = undef;

		#start observing immediatly, if connection is open
		if($hash->{STATE} eq 'opened'){
			Log(3, "[TradfriGateway] Start to observe path $path (start)");
			DevIo_SimpleWrite($hash, "coapObserveStart|coaps://" . $hash->{gatewayAddress} . $path . "\n", 2, 0);
		}
	}
}

#observe all resources, that are stored in the cache. A path is usually stored in the cache when the sub-device is initialized
sub TradfriGateway_StartObserveAll($){
	my ($hash) = @_;
	
	foreach my $observePath ( keys %{$hash->{helper}{observeCache}} ){
		Log(3, "[TradfriGateway] Start to observe path $observePath (auto)");
		DevIo_SimpleWrite($hash, "coapObserveStart|coaps://" . $hash->{gatewayAddress} . $observePath . "\n", 2, 0);
		#sleep(1);
	}
}

# a write command, that is dispatch from the logical module to here via IOWrite requires three arguments:
# 1.: a method for the write command. The following values are allowed:
#		- 'write' -> CoAP-PUT of specified data to a specified path
#		- 'observeStart' -> start the observation of a specified path, argument #3 can be an empty string.
#		- 'get' -> CoAP-GET from a specified path, argument #3 can be an empty string. This call is blocking, the call waits for an answer.
# 2.: the incomplete coap path, like "/15001/65537". The first part of the path will be handled by this module
# 3.: the payload data, for Tradfri as as JSON string
sub TradfriGateway_Write ($@){
	my ( $hash, @arguments) = @_;
	
	if(int(@arguments < 3)){
		Log(1, "[TradfriGateway] Not enough arguments for IOWrite!");
		return "Not enough arguments for IOWrite!";
	}
	
	#@todo better check, if opened
	if($hash->{STATE} ne 'opened'){
		Log(1, "[TradfriGateway] Can't write, connection is not opened!");
		return "Can't write, connection is not opened!";
	}

	if($arguments[0] eq 'write'){
		Log(3, "[TradfriGateway] Put of $arguments[2] to $arguments[1]");
		DevIo_SimpleWrite($hash, "coapPutJSON|coaps://" . $hash->{gatewayAddress} . $arguments[1] . "|" . $arguments[2] . "\n", 2, 0);
	}elsif($arguments[0] eq 'observeStart'){
		TradfriGateway_StartObserve($hash, $arguments[1]);
	}elsif($arguments[0] eq 'get'){
		Log(0, "get: $arguments[1]");
		#@todo check if there is already dat ato read -> call the read function first, before expecting it here
		# this is a little dirty way to check for available data -> to be improved
		my $sel = new IO::Select($hash->{TCPDev});
		if($sel->can_read(0)){
			Log(0, "andere msg in puffer");
			TradfriGateway_Read($hash);
		}

		Log(0, "[TradfriGateway] Get from $arguments[1]");
		my $getReturn = DevIo_Expect($hash, "coapGet|coaps://" . $hash->{gatewayAddress} . $arguments[1] . "\n", 30);
		my @getReturnParts = split(/\|/, $getReturn);
		return $getReturnParts[2] if int(@getReturnParts) >= 3;
		return "UNDEF";
	}

	#@todo return code handling
	return undef;
}

#data was received on the socket
sub TradfriGateway_Read ($){
	my ( $hash ) = @_;

	my $msg = DevIo_SimpleRead($hash);	

	if(!defined($msg)){
		return undef;
	}

	my $msgReadableWhitespace = $msg;
	$msgReadableWhitespace =~ s/\r/\\r/g;
	$msgReadableWhitespace =~ s/\n/\\n/g;
	Log(4, "[TradfriGateway] Received message on socket: \"" . $msgReadableWhitespace . "\"");

	#there might be multiple messages at once, they are split by newline. Iterate through each of them
	my @messagesSingle = split(/\n/, $msg);
	foreach my $message(@messagesSingle){
		#if there is whitespace left, remove it.
		$message =~ s/\r//g;
		$message =~ s/\n//g;

		#dispatch the message if it isn't empty, only dispatch messages that come from an observe
		if(($message ne '') && ((split(/\|/, $message))[0] eq 'observedUpdate')){
			#decode the message here and store it in cache
			#the message contains 'coapObserveStart|coapPath|data' -> split it by the pipe character
			my @parts = split('\|', $message);

			if(int(@parts) < 3){
				#expecting at least three parts
				#if there are not three parts, the message is invalid -> we do not even need to dispatch it
				next;
			}

			#$parts[1], the coapPath is build up like this: coaps://Ip-or-dns-of-gateway/15001/Id-of-device
			#extract the path after the Ip-Or-DNS part
			my ($unused, $path) = ($parts[1] =~ /(^coap.?:\/\/[^\/]*\/)([0-9\/]*)/);
			#re-append a '/' in front of the path
			$path = '/' . $path;

			#parse the JSON data
			my $jsonData = eval{ JSON->new->utf8->decode($parts[2]) };
			if(!($@)){
				#if there is some valid json, then put it into the cache
				$jsonData->{'state'} = "OK";
				$hash->{helper}{observeCache}{"$path"} = $jsonData;
				$hash->{helper}{observeCache}{"$path"}->{'state'} = 'OK';
			}else{
				#no valid json, probably not found
				$hash->{helper}{observeCache}{"$path"}->{'state'} = "Not Found";
			}

			#updates for devices get written to groups too, but in a own function
			#first: check if the observe update was for a device, group updates get dispatched in the "old-fashioned" way
			if($path =~ /^\/15001\/.*/){
				#iterate through each definition of TradfriGroup
				foreach my $TradfriGroup_id ( keys %{$modules{TradfriGroup}{defptr}}){
					no strict "refs";
					&{$modules{TradfriGroup}{ParseDeviceUpdateFn}}($modules{TradfriGroup}{defptr}{$TradfriGroup_id}, $hash, $path);
					use strict "refs";
				}
			}

			#Log(0, Dumper(\%observeCache));

			Dispatch($hash, $message, undef);
		}
	}
}

sub TradfriGateway_Ready($){
	my ($hash) = @_;
	return DevIo_OpenDev($hash, 1, "TradfriGateway_DeviceInit") if($hash->{STATE} eq "disconnected");
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
		my $jsonText = TradfriGateway_Write($hash, 'get', PATH_DEVICE_ROOT, '');

		if(!defined($jsonText)){
			return "Error while fetching devices!";
		}
		
		#parse the JSON data
		my $deviceIDList = eval{ JSON->new->utf8->decode($jsonText) };
		if($@){
			return "Unknown JSON:\n" . $jsonText; #the string was probably not valid JSON
		}

		my $returnUserString = "";

		#@todo read the device info
		for(my $i = 0; $i < scalar(@{$deviceIDList}); $i++){
			$returnUserString .= "- " . 
				${$deviceIDList}[$i] . 
			#	": " . 
			#	TradfriLib::getDeviceManufacturer($deviceInfo) .
			#	" " .
			#	TradfriLib::getDeviceType($deviceInfo) .
			#	" (" .
			#	TradfriLib::getDeviceName($deviceInfo) .
			#	")" .
				"\n";
		}

		return $returnUserString;
	}elsif($opt eq 'groupList'){
		my $jsonText = TradfriGateway_Write($hash, 'get', PATH_GROUP_ROOT, '');

		if(!defined($jsonText)){
			return "Error while fetching groups!";
		}
		
		#parse the JSON data
		my $groupIDList = eval{ JSON->new->utf8->decode($jsonText) };
		if($@){
			return "Unknown JSON:\n" . $jsonText; #the string was probably not valid JSON
		}

		my $returnUserString = "";

		#@todo read group info
		for(my $i = 0; $i < scalar(@{$groupIDList}); $i++){
			$returnUserString .= "- " .
				${$groupIDList}[$i] .
				#": " .
				#TradfriLib::getGroupName($groupInfo) . 
				"\n";

		}

		return $returnUserString;
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

	if($opt eq "reopen"){
		#close connection to socket, if open
		DevIo_CloseDev($hash);
		#@todo react to return code
		my $ret = DevIo_OpenDev($hash, 0, "TradfriGateway_DeviceInit");
	}

	return undef;
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

=pod

=item device
=item summary connects with an IKEA Trådfri gateway 
=item summary_DE stellt die Verbindung mit einem IKEA Trådfri Gateway her

=begin html

<a name="TradfriGateway"></a>
<h3>TradfriGateway</h3>
<ul>
    <i>TradfriGateway</i> stores the connection data for an IKEA Trådfri gateway. It is necessary for TradfriDevice and TradfriGroup
    <br><br>
    <a name="TradfriGatewaydefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; TradfriGateway &lt;gateway-ip&gt; &lt;gateway-secret&gt;</code>
        <br><br>
        Example: <code>define trGateway TradfriGateway TradfriGW.int.kappelt.net vBkxxxxxxxxxx7hz</code>
        <br><br>
        The IP can either be a "normal" IP-Address, like 192.168.2.60, or a DNS name (like shown above).<br>
        You can find the secret on a label on the bottom side of the gateway.
        The parameter "coap-client-path" is isn't used anymore and thus not shown here anymore. Please remove it as soon as possible, if you are still using it.<br>
		You need to run kCoAPSocket running in background, that acts like a translator between FHEM and the Trådfri Gateway.
    </ul>
    <br>
    
    <a name="TradfriGatewayset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; [&lt;value&gt;]</code>
        <br><br>
        You can set the following options. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>reopen</i><br>
                  Re-open the connection to the Java TCP socket, that acts like a "translator" between FHEM and the Tradfri-CoAP-Infrastructure.<br>
                  If the connection is already opened, it'll be closed and opened.<br>
                  If the connection isn't open yet, a try to open it will be executed.<br>
                  <b>Caution: </b>Running this command seems to trigger some issues! Do <i>not</i> run it before a update is available!</li>
        </ul>
    </ul>
    <br>

    <a name="TradfriGatewayget"></a>
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
              <li><i>coapClientVersion</i><br>
                  Get the version of the coap-client. If this command returns "UNKNOWN", the coap-client command can't be called.<br>
                  If coap-client was executed, it'll return the version string and set the reading "coapClientVersion" to the value.</li>
              <li><i>deviceList</i><br>
                  Returns a list of all devices, that are paired with the gateway.<br>
                  The list contains the device's address, its type and the name that was set by the user.</li>
              <li><i>groupList</i><br>
                  Returns a list of all groups, that are configured in the gateway.<br>
                  The list contains the group's address and its name.</li>
        </ul>
    </ul>
    <br>
    
    <a name="TradfriGatewayattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i></i><br>
            	There are no custom attributes implemented
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut