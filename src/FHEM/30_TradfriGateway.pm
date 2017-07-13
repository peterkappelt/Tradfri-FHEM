# @author Peter Kappelt
# @version 1.16.dev-cf.2

package main;
use strict;
use warnings;

use TradfriLib;

require 'DevIo.pm';

my %TradfriGateway_sets = (
	'reopen'	=> ' ',
);

my %TradfriGateway_gets = (
	'deviceList'	=> ' ',
	'groupList'		=> ' ',
	'coapClientVersion'		=> ' ',
);

sub checkCoapClient{
	#check, if coap-client software exists. Set the Reading 'coapClientVersion' to the first line of the programm call's output
	my $coapClientReturnMessage = `coap-client 2>&1`;
	if($coapClientReturnMessage eq ''){
		#empty return -> error
		$_[0]->{canConnect} = 0;
		return "UNKNOWN";
	}else{
		readingsSingleUpdate($_[0], 'coapClientVersion', (split(/\n/, $coapClientReturnMessage))[0], 0);
		$_[0]->{canConnect} = 1;
		return (split(/\n/, $coapClientReturnMessage))[0];
	}
}

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
		return "too few parameters: define <name> TradfriGateway <gateway-ip> <gateway-secret> [<coap-client-directory>]";
	}

	#close connection to socket, if open
	DevIo_CloseDev($hash);
	
	$hash->{name}  = $param[0];

	$hash->{gatewayAddress} = $param[2];
	$hash->{gatewaySecret} = $param[3];

	# @todo make user settable
	$hash->{DeviceName} = "localhost:1505";

	if(int(@param) > 4){
		#there was a fifth parameter
		#it is the path to the coap client, add it to the environments path
		$ENV{PATH}="$ENV{PATH}:" . $param[4];
	}

	#$hash->{STATE} = "INITIALIZED";

	#if(checkCoapClient($hash) ne "UNKNOWN"){
	#	$hash->{STATE} = "IDLE";
	#}

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

	#@todo restart observing the necessary pathes

	#set the PSK
	DevIo_SimpleWrite($hash, "setPSK|" . $hash->{gatewaySecret} . "\n", 2, 0);
}

# a write command, that is dispatch from the logical module to here via IOWrite requires three arguments:
# 1.: a method for the write command. The following values are allowed:
#		- 'write' -> CoAP-PUT of specified data to a specified path
#		- 'observeStart' -> start the observation of a specified path, argument #3 can be an empty string.
#		- 'get' -> CoAP-GET from a specified path, argument #3 can be an empty string. This call is blocking, the call waits for an answer.
# 2.: the incomplete coap path, like "/15001/65537". The first part of the path will be handled by this module
# 3.: the payload data, for Tradfri as as JSON string
sub TradfriGateway_Write ($$){
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
		Log(3, "[TradfriGateway] Start to observe path $arguments[1]");
		DevIo_SimpleWrite($hash, "coapObserveStart|coaps://" . $hash->{gatewayAddress} . $arguments[1] . "\n", 2, 0);
	}elsif($arguments[0] eq 'get'){
		Log(4, "[TradfriGateway] Get from $arguments[1]");
		return DevIo_Expect($hash, "coapGet|coaps://" . $hash->{gatewayAddress} . $arguments[1] . "\n", 1);
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

		#dispatch the message if it isn't empty
		if($message ne ''){
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
		my $deviceIDList = TradfriLib::getDevices($hash->{gatewayAddress}, $hash->{gatewaySecret});
			
		if(!defined($deviceIDList)){
			return "Error while trying to fetch devices!";
		}

		my $returnUserString = "";

		for(my $i = 0; $i < scalar(@{$deviceIDList}); $i++){
			my $deviceInfo = TradfriLib::getDeviceInfo($hash->{gatewayAddress}, $hash->{gatewaySecret}, ${$deviceIDList}[$i]);
			$returnUserString .= "- " . 
				${$deviceIDList}[$i] . 
				": " . 
				TradfriLib::getDeviceManufacturer($deviceInfo) .
				" " .
				TradfriLib::getDeviceType($deviceInfo) .
				" (" .
				TradfriLib::getDeviceName($deviceInfo) .
				")" .
				"\n";
		}

		return $returnUserString;
	}elsif($opt eq 'groupList'){
		my $groupIDList = TradfriLib::getGroups($hash->{gatewayAddress}, $hash->{gatewaySecret});

		if(!defined($groupIDList)){
			return "Error while fetching groups!";
		}

		my $returnUserString = "";

		for(my $i = 0; $i < scalar(@{$groupIDList}); $i++){
			my $groupInfo = TradfriLib::getGroupInfo($hash->{gatewayAddress}, $hash->{gatewaySecret}, ${$groupIDList}[$i]);

			$returnUserString .= "- " .
				${$groupIDList}[$i] .
				": " .
				TradfriLib::getGroupName($groupInfo) . 
				"\n";

		}

		return $returnUserString;
	}elsif($opt eq 'coapClientVersion'){
		return checkCoapClient($hash);
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
        <code>define &lt;name&gt; TradfriGateway &lt;gateway-ip&gt; &lt;gateway-secret&gt; [&lt;coap-client-path&gt;]</code>
        <br><br>
        Example: <code>define trGateway TradfriGateway TradfriGW.int.kappelt.net vBkxxxxxxxxxx7hz</code>
        <br><br>
        The IP can either be a "normal" IP-Address, like 192.168.2.60, or a DNS name (like shown above).<br>
        You can find the secret on a label on the bottom side of the gateway.
        The parameter "coap-client-path" is only necessary, if the module cannot find the coap-client you've installed before.
        See the github page (<a href="https://github.com/peterkappelt/Tradfri-FHEM#debugging-get-coapclientversion--unknown">
        									https://github.com/peterkappelt/Tradfri-FHEM#debugging-get-coapclientversion--unknown
        									</a>) for further information.<br>
		<br>
        In order to define a gateway and connect to it, you need to install the software "coap-client" on your system. See <a href="https://github.com/peterkappelt/Tradfri-FHEM#prerequisites">
        									https://github.com/peterkappelt/Tradfri-FHEM#prerequisites
        									</a>
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
                  If the connection isn't open yet, a try to open it will be executed.</li>
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