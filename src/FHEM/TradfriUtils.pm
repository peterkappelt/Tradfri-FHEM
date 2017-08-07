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

sub Tradfri_setBrightness($$$){
        my ($hash, $dimpercent, $address) = @_;
        readingsSingleUpdate($hash, "pct", $dimpercent, 1);
        $hash->{STATE} = Tradfri_stateString($dimpercent);
        
	if( $dimpercent == 0 ){
		return IOWrite($hash, 1, 'set', $address, "onoff::0");
	}else{
        	my $dimvalue = int($dimpercent * 2.54 + 0.5);
		readingsSingleUpdate($hash, "dimvalue", $dimvalue, 1);
		return IOWrite($hash, 1, 'set', $address, "dimvalue::$dimvalue");
	}
}
