# @author Clemens Bergmann
# @author Peter Kappelt  (small changes)
# @version 1.16.dev-cf.7

package main;
use strict;
use warnings;

use SetExtensions;

my %dim_values = (
		0 => "dim06%",
		1 => "dim12%",
		2 => "dim18%",
		3 => "dim25%",
		4 => "dim31%",
		5 => "dim37%",
		6 => "dim43%",
		7 => "dim50%",
		8 => "dim56%",
		9 => "dim62%",
		10 => "dim68%",
		11 => "dim75%",
		12 => "dim81%",
		13 => "dim87%",
		14 => "dim93%",
);

sub Tradfri_devStateIcon($){
	my ($name) = @_;
	my $pct = ReadingsVal($name,"pct","100");
	my $s = $dim_values{int($pct/7)};
	$s="on" if( $pct eq "100" );
	$s="off" if( $pct eq "0" );
	return ".*:$s:toggle";
}

#get the on state of the group depending on the dimm value
sub Tradfri_stateString($){
	my ($value) = @_;
	if($value <= 0){
		return 'off';
	}elsif($value >= 99){
		return 'on';
	}else{
		return "dim$value%";
	}
}

sub Tradfri_setBrightness($$){
	my ($hash, $dimpercent) = @_;
	#readingsSingleUpdate($hash, "pct", $dimpercent, 1);
	$hash->{STATE} = Tradfri_stateString($dimpercent);
	my $address = $hash->{address};

	#type, can be device or group
	my $type;
	if($hash->{TYPE} eq 'TradfriGroup'){
		$type = 1;
	}elsif($hash->{TYPE} eq 'TradfriDevice'){
		$type = 0;
	}else{
		Log(0, "[Tradfri] Trying to call Tradfri-Functions with a non-Tradfri device (with $hash->{TYPE}");
	}

	if( $dimpercent == 0 ){
		return IOWrite($hash, $type, 'set', $address, "onoff::0");
	}else{
		my $dimvalue = int($dimpercent * 2.54 + 0.5);
		#readingsSingleUpdate($hash, "dimvalue", $dimvalue, 1);
		return IOWrite($hash, $type, 'set', $address, "dimvalue::$dimvalue");
	}
}

sub Tradfri_Set($@) {
	my ($hash, $name, $opt, @param) = @_;

	return "\"set $hash->{TYPE}\" needs at least one argument" unless(defined($opt));

	my $value = join("", @param);

	#parameters that can be set
	my $cmdList = "on off pct:colorpicker,BRI,0,1,100";

	#dynamic option: dimvalue depends on attribute usePercentDimming
	my $dimvalueMax = 254;
	$dimvalueMax = 100 if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
	$cmdList .= " dimvalue:slider,0,1,$dimvalueMax";

	#parameters that are only applicable to devices
	if($hash->{TYPE} eq 'TradfriDevice'){
		$cmdList .= " color:warm,cold,standard" ;
	}

	#parameters that are only applicable to groups
	if($hash->{TYPE} eq 'TradfriGroup'){
		#dynamic option: moods
		my $moodsList = join(",", map { "$_" } keys %{$hash->{helper}{moods}});
		$cmdList .= " mood:$moodsList" 
	}

	if ($opt eq "toggle") {
		$opt = (ReadingsVal($hash->{name}, 'onoff', 0) eq 'off') ? "on" : "off";
	}elsif($opt eq "on"){
		my $dimpercent = ReadingsVal($hash->{name}, 'dimvalue', 254);
		$dimpercent = int($dimpercent / 2.54 + 0.5) if(AttrVal($hash->{name}, 'usePercentDimming', 0) == 0);
		#@todo ist das Setzen der Helligkeit hier angebracht, welche Auswirkungen hat das? Fehlerfälle betrachten!, evtl. nur einschalten?
		Tradfri_setBrightness($hash,$dimpercent);
	}elsif($opt eq "off"){
		Tradfri_setBrightness($hash,0);
	}elsif($opt eq "dimvalue"){
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 254!'  if ! @param;

		my $dimpercent = int($value);
		$dimpercent = int($value / 2.54 + 0.5) if(AttrVal($hash->{name}, 'usePercentDimming', 0) == 0);

		Tradfri_setBrightness($hash,$dimpercent);
	}elsif($opt eq "pct"){
		return '"set TradfriDevice dimvalue" requires a brightness-value between 0 and 100!'  if ! @param;

		Tradfri_setBrightness($hash,int($value));
	}elsif(($hash->{TYPE} eq 'TradfriGroup') and ($opt eq "mood")){
		return '"set TradfriGroup mood" requires a mood ID or a mood name. You can list the available moods for this group by running "get moods"'  if ! @param;

		if(!($value =~ /[1-9]+/)){
			#user wrote a string -> a mood name
			if(exists($hash->{helper}{moods}->{"$value"})){
				$value = $hash->{helper}{moods}->{"$value"}->{moodid};
			}else{
				return "Unknown mood!";
			}
		}

		return IOWrite($hash, 1, 'set', $hash->{address}, "mood::$value");
	}elsif(($hash->{TYPE} eq 'TradfriDevice') and ($opt eq "color")){
		return '"set TradfriDevice color" requires RGB value in format "RRGGBB" or "warm", "cold", "standard"!'  if ! @param;

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

		return IOWrite($hash, 0, 'set', $hash->{address}, "color::$rgb");
	}else{
		return SetExtensions($hash, $cmdList, $name, $opt, @param);
	}

	return undef;
}

sub Tradfri_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
}

sub Tradfri_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
		if($attr_name eq ""){

		}
	}
	return undef;
}

sub Tradfri_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);

	if(int(@param) < 3) {
		return "too few parameters: define <name> $hash->{TYPE} <Address>";
	}

	$hash->{name}  = $param[0];
	$hash->{address} = $param[2];

	#$attr{$hash->{name}}{webCmd} = 'pct:toggle:on:off';
	#$attr{$hash->{name}}{devStateIcon} = '{(Tradfri_devStateIcon($name),"toggle")}' if( !defined( $attr{$hash->{name}}{devStateIcon} ) );

	AssignIoPort($hash);

	#start observing the coap resource, so the module will be informed about status updates
	#@todo stop observing, when deleting module, or stopping FHEM

	#reverse search, for Parse
	$modules{$hash->{TYPE}}{defptr}{$hash->{address}} = $hash;
	if($hash->{TYPE} eq 'TradfriDevice'){
		IOWrite($hash, 0, 'subscribe', $hash->{address});
	}elsif($hash->{TYPE} eq 'TradfriGroup'){
		IOWrite($hash, 1, 'subscribe', $hash->{address});
		#update the moodlist
		IOWrite($hash, 1, 'moodlist', $hash->{address});
	}

	return undef;
}

sub Tradfri_Get($@) {
	my ($hash, @param) = @_;

	return "\"get $hash->{TYPE}\" needs at least one argument" if (int(@param) < 2);

	my $name = shift @param;
	my $opt = shift @param;

	my $cmdList = "";

	#Only applicable for groups: moods list
	$cmdList .= " moods" if($hash->{TYPE} eq 'TradfriGroup');	

	#$cmdList .= " groupInfo" if($hash->{TYPE} eq 'TradfriGroup');	
	#$cmdList .= " deviceInfo" if($hash->{TYPE} eq 'TradfriDevice');	

	if($hash->{TYPE} eq 'TradfriGroup' and $opt eq 'moods'){
		IOWrite($hash, 1, 'moodlist', $hash->{address});
		return undef
		#return '';
#	}elsif($hash->{TYPE} eq 'TradfriGroup' and $opt eq 'groupInfo'){
#	}elsif($hash->{TYPE} eq 'TradfriDevice' and $opt eq 'deviceInfo'){
#		my $jsonText = IOWrite($hash, 'get', PATH_DEVICE_ROOT . "/" . $hash->{address}, '');
#
#               if(!defined($jsonText)){
#                     return "Error while fetching device info!";
#               }
#               
#               #parse the JSON data
#               my $jsonData = eval{ JSON->new->utf8->decode($jsonText) };
#               if($@){
#                     return $jsonText; #the string was probably not valid JSON
#               }
#
#               return Dumper($jsonData);
	}else{
		return "Unknown argument $opt, choose one of $cmdList";
	}
}
