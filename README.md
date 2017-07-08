# FHEM Trådfri Module

This is a small extension module for the FHEM Home-Control software. It enables connectivity to an IKEA Trådfri gateway.

## About this branch (cf-dev)

This branch is used to evaluate other options for CoAP clients, here Eclipse Californium. It is one step into the direction of realtime updating of the device parameters.

__Caution:__ The information down below might __not__ be up to date, it'll be updated later.

## Install to FHEM
Run the following commands to add this repository to your FHEM setup:
```
update add https://raw.githubusercontent.com/peterkappelt/Tradfri-FHEM/master/src/controls_tradfri.txt
update
shutdown restart
```

Since there is no documentation yet, FHEM might throw some errors during update. Don't worry about them.

## Prerequisites

**Summary:**
* Perl JSON packages (JSON.pm), on my setups they can be installed by running `sudo apt-get install libjson-perl`
* libcoap, and its binary coap-client
* IKEA devices: a gateway, a bulb and a remote control/ dimmer

You need to have an IKEA Trådfri Bulb or Panel, a Control-Device (e.g. the Dimmer) and the Gateway.  
The gateway has to be set-up with the App, the control device and the bulbs need to be paired.  
__Caution__: Do not make the same mistake I've made. You can __not__ just buy a bulb and a gateway. You need a control device, like the round dimmer, too!

The JSON-Perl packages are required.

Furthermore, you need to install the software "libcoap". You can find its repository here: https://github.com/obgm/libcoap  
This library needs to be built, have a look into its documentation. I've run the following commands:
```
sudo apt-get install libtool

git clone --recursive https://github.com/obgm/libcoap.git
cd libcoap
git checkout dtls
git submodule update --init --recursive
./autogen.sh
./configure --disable-documentation --disable-shared
make
sudo make install
```
Note: An user reported, that he had to install "autoconf" on his system. You can just run "sudo apt-get install autoconf" on your system.

## What this module can do

You can currently do the following with the devices.
Please note, that this module is still in development and there will be new functionality.  

|  | Devices | Groups |  
| ---:|:---:|:---:|  
| Turn on/ off | X | X |  
| Get on/ off state | X | X |
| Update on/ off state periodically | X | X |
| Update on/ off state in realtime |||
| Set brightness | X | X |
| Get brightness | X | X |
| Update brightness periodically | X | X |
| Update brightness in realtime |||
| Set the color temperature | X |--|
| Get the color temperature | X |--|
| Update the color periodically | X |--|
| Update the color in realtime ||--|
| Set the mood |--|X|
| Get the mood |--||
| Get information about a mood |--||
| Update the mood periodically |--||
| Update the mood in realtime |--||

Additional features:
* Get information about a bulb, e.g. firmware version, type and reachable state
* Get the IDs of all devices that are connected to the gateway
* Get the IDs of all groups that are configured in the gateway
* Get the IDs of all moods that are configured for a group

...and some more features, that aren't listed here (but in the FHEM command reference)
## What this module can not do
These points will be implemented later:
* Pair new devices, set group memberships
* Moods can't be modified, added

## Getting started
You need to do as follows in order to control a bulb:
### 1. Declare the Gateway-Connection

* Define a new device in you FHEM setup: `define TradfriGW TradfriGateway <Gateway-IP> <Gateway-Secret-Key>`.
* Don't forget to install the Perl JSON packages (JSON.pm). See "Prerequisites" for a hint how I've installed them.
* You can use the gateway's IP address or its DNS name
* You can find the Secret Key on the bottom side of your gateway. It is marked as the "Security Code".
* Save your config by running the `save` command in FHEM 
* Check, whether the module can detect and access the just compiled software "coap-client" by running `get TradfriGW coapClientVersion`. If it returns something, that looks like a version number, everything should be fine. If it returns "UNKNOWN" there is a problem. Probably, the coap-client directory is not stored in path.

#### Debugging get coapClientVersion = UNKNOWN
* run `which coap-client` on the system command line. If this command returns nothing, it is likely, that there was an error while compiling and installing libcoap. 
* On my system, it returns "/usr/local/bin/coap-client"
* Remove the last part from the path and remember it, now I've got "/usr/local/bin"
* Edit the definition of the gateway device and append the coap path to its definition: `defmod TradfriGW TradfriGateway <Gateway-IP> <Gateway-Secret-Key> /usr/local/bin`
* For those, who are used to linux: The third parameter adds something to the FHEM PATH-variable, so the module is able to locate the coap-client
### 2. Control a single device
* Get the list of devices: `get TradfriGW deviceList`. It will return something like that:  
   ```
   - 65536: IKEA of Sweden TRADFRI wireless dimmer (TRADFRI wireless dimmer) 
   - 65537: IKEA of Sweden TRADFRI bulb E27 opal 1000lm (Fenster Links) 
   - 65538: IKEA of Sweden TRADFRI bulb E27 opal 1000lm (Fenster Rechts) 
   ```   
   In my setup, there are three devices: Two bulbs and one control unit. The devices are labeled with the names you configured in the app.  
* Define a new device, with one of the adresses you've just found out (it must be a bulb's address, this module is unable to interact with controllers): `define Bulb1 TradfriDevice 65537`
* Check, if the gateway device was asigned correctly as the IODev
* You can now control this device:  
   `set Bulb1 on` will turn the lamp on  
   `set Bulb1 off` will turn the lamp off  
   `set Bulb1 dimvalue x` will set the lamp's brightness, where x is between 0 and 254   
   `set Bulb1 color warm` will set the lamp to warm-white (if supported)
* If you like to set the color temperature and the brightness directly in the web-interface, set the attribute webCmd to `dimvalue:color`
* You can get additional information about controlling devices in the automatically generated FHEM HTML command reference, under TradfriDevice
### 3. Control a lighting group
* Get the list of groups: `get TradfriGW groupList`. It will return something like that:  
   ```
   - 193768: Wohnzimmer
   ```   
   In my setup, there is only one group called "Wohnzimmer".
* Define a new group, with one of the adresses you've just found out: `define Group1 TradfriGroup 193768`
* Check, if the gateway device was asigned correctly as the IODev
* You can now control this group, like a single device:  
   `set Group1 on` will turn all devices in the group on  
   `set Group1 off` will turn all devices in the group off
   `set Group1 dimvalue x` will set all brightnesses of the group to a certain value, where x is between 0 and 254 
* If you like to set the brightness directly in the web-interface, set the attribute webCmd to `dimvalue`
* You can get additional information about controlling groups in the automatically generated FHEM HTML command reference, under TradfriGroup

## What to do, if my FHEM isn't responding anymore?

Actually, this shouldn't happen anymore. Wait 5 seconds, and all processes, that are related to this Trådfri module, should kill themselves (if there is a configuration error, that isn't yet handled by this module).    
If you managed to kill this module, fell free to contact me (with your log, you configuration and a description, of what you did to make FHEM unresponsible).

## Credits
I'd like to thank the guys from the home-assistant.io community, they already did some reverse-engineering of the protocol, which helped me implementing the protocol.   
https://community.home-assistant.io/t/ikea-tradfri-gateway-zigbee/14788/18

## Manual

This manual, in its up-to-date version, for this module, and a translation, is available on my website.
See <http://electronic.kappelt.net/wordpress/en/ikea-tradfri-module-for-fhem/> (English) oder
<http://electronic.kappelt.net/wordpress/de/ikea-tradfri-module-for-fhem/> (Deutsch).
You may also leave a comment there. A FAQ page will be created soon.

## Contact me

If you've a github account: please open an issue, with the appropriate description of your problem.
You may send me an email, though issues are prefered: <kappelt.peter@gmail.com>
