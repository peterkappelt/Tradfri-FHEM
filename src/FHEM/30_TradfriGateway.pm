# @author Peter Kappelt
# @author Sebastian Keßler

# @version 1.16.dev-cf.10

package main;
use strict;
use warnings;

require 'DevIo.pm';

my %TradfriGateway_sets = (
	#'reopen'	=> ' ',
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

	$hash->{Clients}	= "TradfriDevice:TradfriGroup";
	$hash->{MatchList} = {
			"1:TradfriDevice" => '^subscribedDeviceUpdate::',
			"2:TradfriGroup" => '(^subscribedGroupUpdate::)|(^moodList::)' ,
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

	if(int(@param) > 4){
		#there was a fifth parameter
		#it is the path to the coap client, add it to the environments path
		#Edit: it is obsolete now! Give advice to the user
		Log(0, "[TradfriGateway] The parameter \"coap-client-directory\" in the gateway's definition is obsolete now! Please remove it as soon as possible!")
	}

	#open the socket connection
	#@todo react to return code
	DevIo_OpenDev($hash, 0, "TradfriGateway_DeviceInit");

	return undef;
}

sub TradfriGateway_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub TradfriGateway_DeviceInit($){
	my $hash = shift;

	#subscribe to all devices and groups, update the moodlist of the group
	#@todo check, whether we this instance is the IODev of the device/ group
	foreach my $deviceID ( keys %{$modules{'TradfriDevice'}{defptr}}){
		TradfriGateway_Write($hash, 0, 'subscribe', $deviceID);
	}

	foreach my $groupID ( keys %{$modules{'TradfriGroup'}{defptr}}){
		TradfriGateway_Write($hash, 1, 'subscribe', $groupID);
		TradfriGateway_Write($hash, 1, 'moodlist', $groupID);
	}
}


# a write command, that is dispatch from the logical module to here via IOWrite requires at least two arguments:
# - 1. Scope: 				Group (1) or Device (0)
# - 2. Action	: 			A command:
#								* list -> sets the readings groups/ devices
#								* moodlist (groups only) -> get all moods that are defined for this group
#								* subscribe -> subscribe to updated of that specific device
#								* set -> write a specific value to the group/ device
# - 3. ID:					ID of the group or device
# - 4. attribute::value		only for command set, attribute can be onoff, dimvalue, mood (groups only), color (devices only) or name
sub TradfriGateway_Write ($@){
	my ( $hash, $groupOrDevice, $action, $id, $attrValue) = @_;
	
	if(!defined($groupOrDevice) && !defined($action)){
		Log(1, "[TradfriGateway] Not enough arguments for IOWrite!");
		return "Not enough arguments for IOWrite!";
	}

	my $command = '';

	#for cmd-buildup: decide on group/ device
	if($groupOrDevice){
		$command .= 'group::';
	}else{
		$command .= 'device::';
	}

	if($action eq 'list'){
		$command .= 'list';
	}elsif($action eq 'moodlist'){
		$command .= "moodlist::${id}";
	}elsif($action eq 'subscribe'){
		#silently return if connection is open.
		#at startup, every device/ group runs subscribe. If the connection isn't open, we do it later.
		return if($hash->{STATE} ne 'opened');
		$command .= "subscribe::${id}";
	}elsif($action eq 'set'){
		$command .= "set::${id}::${attrValue}";
	}else{
		return "Unknown command: " . $command;
	}

	#@todo better check, if opened
	if($hash->{STATE} ne 'opened'){
		Log(1, "[TradfriGateway] Can't write, connection is not opened!");
		return "Can't write, connection is not opened!";
	}

	DevIo_SimpleWrite($hash, $command . "\n", 2, 0);

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

		#devices and groups
		#@todo not as JSON array
		if(($message ne '') && ((split(/::/, $message))[0] =~ /(?:group|device)List/)){
			if((split(/::/, $message))[0] eq 'deviceList'){
				readingsSingleUpdate($hash, 'devices', (split(/::/, $message))[1], 1);
			}
			if((split(/::/, $message))[0] eq 'groupList'){
				readingsSingleUpdate($hash, 'groups', (split(/::/, $message))[1], 1);
			}
		}

		#dispatch the message if it isn't empty, only dispatch messages that come from an observe
		if(($message ne '') && ((split(/::/, $message))[0] =~ /(?:subscribed(?:Group|Device)Update)|(?:moodList)/)){
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
		TradfriGateway_Write($hash, 0, 'list');
	}elsif($opt eq 'groupList'){
		TradfriGateway_Write($hash, 1, 'list');
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
              <li><i>deviceList</i><br>
                  Sets the reading "devices" to a JSON-formatted string of all device IDs and their names.</li>
              <li><i>groupList</i><br>
                  Sets the reading "devices" to a JSON-formatted string of all group IDs and their names.</li>
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
