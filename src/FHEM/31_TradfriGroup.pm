# @author Peter Kappelt
# @author Clemens Bergmann
# @version 1.16.dev-cf.9

package main;
use strict;
use warnings;

use Data::Dumper;
use JSON;

use TradfriUtils;

sub TradfriGroup_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'Tradfri_Define';
	$hash->{UndefFn}    = 'Tradfri_Undef';
	$hash->{SetFn}      = 'Tradfri_Set';
	$hash->{GetFn}      = 'Tradfri_Get';
	$hash->{AttrFn}     = 'Tradfri_Attr';
	$hash->{ReadFn}     = 'Tradfri_Read';
	$hash->{ParseFn}	= 'TradfriGroup_Parse';

	$hash->{Match} = '(^subscribedGroupUpdate::)|(^moodList::)';

	$hash->{AttrList} =
		"usePercentDimming:1,0 "
		. $readingFnAttributes;
}


#messages look like this: (without newlines)
# subscribedGroupUpdate::group-id::{
#    "createdAt":1494088484,
#    "mood":198884,
#    "groupid":173540,
#    "members":[
#       {
#          "name":"Fenster Links",
#          "deviceid":65537
#       },
#       {
#          "deviceid":65536
#       },
#       {
#          "name":"Fenster Rechts",
#          "deviceid":65538
#       }
#    ],
#    "name":"Wohnzimmer",
#    "dimvalue":200,
#    "onoff":0
# }
sub TradfriGroup_Parse($$){
	my ($io_hash, $message) = @_;
	
	my @parts = split('::', $message);

	if(int(@parts) < 3){
		#expecting at least three parts
		return undef;
	}

	my $messageID = $parts[1];

	#check if group with the id exists
	if(my $hash = $modules{'TradfriGroup'}{defptr}{$messageID}) 
	{
		#parse the JSON data
		my $jsonData = eval{ JSON->new->utf8->decode($parts[2]) };
		if($@){
			return undef; #the string was probably not valid JSON
		}

		if('subscribedGroupUpdate' eq $parts[0]){
			my $createdAt = FmtDateTimeRFC1123($jsonData->{'createdAt'} || '');
			my $name = $jsonData->{'name'} || '';
			my $members = JSON->new->pretty->encode($jsonData->{'members'});
			
			#dimvalue is in range 0 - 254
			my $dimvalue = $jsonData->{'dimvalue'} || '0';
			#dimpercent is always in range 0 - 100
			my $dimpercent = int($dimvalue / 2.54 + 0.5);
			$dimpercent = 1 if($dimvalue == 1);
			$dimvalue = $dimpercent if (AttrVal($hash->{name}, 'usePercentDimming', 0) == 1);
			
			my $state = 'off';
            if($jsonData->{'onoff'} eq '0'){
				$dimpercent = 0;
			}else{
               	$state = Tradfri_stateString($dimpercent);
            }

            my $onoff = ($jsonData->{'onoff'} || '0') ? 'on':'off';

			readingsBeginUpdate($hash);
			readingsBulkUpdateIfChanged($hash, 'createdAt', $createdAt, 1);
			readingsBulkUpdateIfChanged($hash, 'name', $name, 1);
			readingsBulkUpdateIfChanged($hash, 'members', $members, 1);
			readingsBulkUpdateIfChanged($hash, 'dimvalue', $dimvalue, 1);
			readingsBulkUpdateIfChanged($hash, 'pct', $dimpercent, 1);
			readingsBulkUpdateIfChanged($hash, 'onoff', $onoff, 1) ;
			readingsBulkUpdateIfChanged($hash, 'state', $state, 1);
			readingsEndUpdate($hash, 1);
		}elsif('moodList' eq $parts[0]){
			#update of mood list
			readingsSingleUpdate($hash, 'moods', JSON->new->pretty->encode($jsonData), 1);

			$hash->{helper}{moods} = undef;
			foreach (@{$jsonData}){
				$hash->{helper}{moods}->{$_->{name}} = $_;
			}
		}

		#$attr{$hash->{NAME}}{webCmd} = 'pct:toggle:on:off';
        #$attr{$hash->{NAME}}{devStateIcon} = '{(Tradfri_devStateIcon($name),"toggle")}' if( !defined( $attr{$hash->{name}}{devStateIcon} ) );
		
		#return the appropriate group's name
		return $hash->{NAME}; 
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
              <li><i>mood</i><br>
                  Set the mood of the group.<br>
                  Moods are preconfigured color temperatures, brightnesses and states for each device of the group<br>
                  In order to set the mood, you need a mood ID or the mood's name.<br>
                  You can list the moods that are available for this group by running "get moods".<br>
                  Note, that the mood's name isn't necessarily the same that you've defined in the IKEA app.
                  This module is currently unable to handle whitespaces in mood names, so whitespaces get removed internally.
                  Check the reading "moods" after running "get moods" in order to get the names, that you may use with this module.<br>
                  Mood names are case-sensitive. Mood names, that are only made out of numbers are not supported.</li>
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
               <li><i>moods</i><br>
                  Get all moods (their name and their ID) that are configured for this group<br>
                  The JSON-formatted result is stored in the Reading "moods"</br>
                  Please note, that the mood IDs may differ between different groups (though they are the same moods) -> check them for each group</li>
        </ul>
    </ul>
    <br>
    
	<a name="TradfriGroupreadings"></a>
    <b>Readings</b><br>
    <ul>
        The following readings are displayed for a group. Once there is a change and the connection to the gateway is made, they get updated automatically.
		<br><br>
        Readings:
        <ul>
              <li><i>createdAt</i><br>
                  A timestamp string, like "Sat, 15 Apr 2017 18:29:24 GMT", that indicates, when the group was created in the gateway.</li>
              <li><i>dimvalue</i><br>
                  The brightness that is set for this group. It is a integer in the range of 0 to 100/ 254.<br>
                  The greatest dimvalue depends on the attribute "usePercentDimming", see below.</li>
              <li><i>pct</i><br>
                  The brightness that is set for this device in percent.</li>
              <li><i>members</i><br>
                  JSON-String that contains all member-IDs and their names.</li>
              <li><i>moods</i><br>
                  JSON info of all moods and their names, e.g.:<br>
                  [ { "groupid" : 173540, "moodid" : 198884, "name" : "EVERYDAY" }, { "moodid" : 213983, "name" : "RELAX", "groupid" : 173540 }, { "groupid" : 173540, "name" : "FOCUS", "moodid" : 206399 } ]<br>
                  This reading isn't updated automatically, you've to call "get moods" in order to refresh them.</li>    
              <li><i>name</i><br>
                  The name of the group that you've set in the app.</li>
              <li><i>onoff</i><br>
                  Indicates whether the device is on or off, can be the strings 'on' or 'off'</li>
              <li><i>state</i><br>
                  Indicates, whether the group is on or off. Thus, the reading's value is either "on" or "off", too.</li>
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
