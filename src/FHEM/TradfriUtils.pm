package main;
use strict;
use warnings;

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
        readingsSingleUpdate($hash, "pct", $dimpercent, 1);
        $hash->{STATE} = Tradfri_stateString($dimpercent);
        
	my $type = 0;
	my $address = $hash->{deviceAddress};
	if( $hash->{TYPE} eq 'TradfriGroup'){
		$type = 1;
		$address = $hash->{groupAddress};
	}

	if( $dimpercent == 0 ){
		return IOWrite($hash, $type, 'set', $address, "onoff::0");
	}else{
        	my $dimvalue = int($dimpercent * 2.54 + 0.5);
		readingsSingleUpdate($hash, "dimvalue", $dimvalue, 1);
		return IOWrite($hash, $type, 'set', $address, "dimvalue::$dimvalue");
	}
}

sub Tradfri_Set($@) {
	my ($hash, $name, $opt, @param) = @_;
	
	return '"set TradfriGroup" needs at least one argument' unless(defined($opt));

	my $value = join("", @param);

	#dynamic option: moods
	my $moodsList = join(",", map { "$_" } keys %{$hash->{helper}{moods}});

	my $dimvalueMax = 254;
        $dimvalueMax = 100 if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
        my $cmdList = "on off pct:colorpicker,BRI,0,1,100 dimvalue:slider,0,1,$dimvalueMax mood:$moodsList";
	
	if ($opt eq "toggle") {
                $opt = (ReadingsVal($hash->{name}, 'pct', 0) == 0) ? "on" : "off";
        }

	if($opt eq "on"){
                my $dimpercent = ReadingsVal($hash->{name}, 'dimvalue', 254);
                $dimpercent = int($dimpercent / 2.54 + 0.5) if(AttrVal($hash->{name}, 'usePercentDimming', 0) == 0);

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
        }elsif($hash->{TYPE} eq 'TradfriGroup' and $opt eq "mood"){
		return '"set TradfriGroup mood" requires a mood ID or a mood name. You can list the available moods for this group by running "get moods"'  if ! @param;
		return IOWrite($hash, 1, 'set', $hash->{groupAddress}, "mood::$value");
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


