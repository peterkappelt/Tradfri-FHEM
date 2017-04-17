# @author Peter Kappelt
# @version 1.2

package main;
use strict;
use warnings;

use Data::Dumper;

use TradfriLib;

my %TradfriGroup_gets = (
	'groupInfo'	=> ' ',
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
}

sub TradfriGroup_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 3) {
		return "too few parameters: define <name> TradfriGroup <GroupAddress>";
	}
   
	$hash->{name}  = $param[0];
	$hash->{groupAddress} = $param[2];
 
	#define empty readings
	readingsSingleUpdate($hash, "state", '???', 0);
	readingsSingleUpdate($hash, "dimvalue", '???', 0);

	AssignIoPort($hash);

	return undef;
}

sub TradfriGroup_Undef($$) {
	my ($hash, $arg) = @_; 
	# nothing to do
	return undef;
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
		my $jsonGroupInfo = TradfriLib::getGroupInfo($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress});
		
		if($jsonGroupInfo ~~ undef){
			return "Error while fetching group info!";
		}

		return(Dumper($jsonGroupInfo));
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
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	$hash->{STATE} = $TradfriGroup_sets{$opt} = $value;

	if($opt eq "on"){
		TradfriLib::groupSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, 1);
		readingsSingleUpdate($hash, 'state', 'on', 1);
	}elsif($opt eq "off"){
		TradfriLib::groupSetOnOff($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, 0);
		readingsSingleUpdate($hash, 'state', 'off', 1);
	}elsif($opt eq "dimvalue"){
		return '"set TradfriGroup dimvalue" requires a brightness-value between 0 and 254!'  if ($argcount < 3);
		TradfriLib::groupSetBrightness($hash->{IODev}{gatewayAddress}, $hash->{IODev}{gatewaySecret}, $hash->{groupAddress}, int($value));
		readingsSingleUpdate($hash, 'dimvalue', int($value), 1);
	}

	return undef;

	#return "$opt set to $value.";
}


sub TradfriGroup_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
#		if($attr_name eq "gatewayIP"){
#			if($attr_value ne ''){
#			}else{
#				return "You need to specify a gateway address!";
#			}
#		}elsif($attr_name eq "gatewaySecret"){
#			if($attr_value ne ''){
#			}else{
#				return "You need to specify a gateway secret!";
#			}
#		}
	}
	return undef;
}

1;
