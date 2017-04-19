# FHEM Trådfri Module

This is a small extension module for the FHEM Home-Control software. It enables connectivity to an IKEA Trådfri gateway.

## Install to FHEM
Run the following commands to add this repository to your FHEM setup:
```
update add https://raw.githubusercontent.com/peterkappelt/Tradfri-FHEM/master/src/controls_tradfri.txt
update
shutdown restart
```

Since there is no documentation yet, FHEM might throw some errors during update. Don't worry about them.

## Prerequisites

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

## What this module can do

Theres's currently only very basic functionality implemented.  
You can:
* Turn a bulb on or off
* Set the brightness of a bulb
* Get information about the bulb, e.g. firmware version and type
* Get the IDs of all devices that are connected to the gateway
* Get the IDs of all groups that are configured in the gateway
* Turn a group on or off
* Set the brightness of a group
## What this module can not do
These points will be implemented later:
* Set the color temperature of a bulb that is able to do that
* Pair new devices
* Read information from the bulb, like the current brightness, and react to it
* Get information about groups, like connected devices

## Getting started
You need to do as follows in order to control a bulb:
### 1. Declare the Gateway-Connection

* Define a new device in you FHEM setup: `define TradfriGW TradfriGateway <Gateway-IP> <Gateway-Secret-Key>`.  
* You can use the gateway's IP address or its DNS name
* You can find the Secret Key on the bottom side of your gateway. It is marked as the "Security Code".
* Save your config by running the `save` command in FHEM 

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

## What to do, if my FHEM isn't responding anymore?

Actually, this shouldn't happen anymore. Wait 5 seconds, and all processes, that are related to this Trådfri module, should kill themselves (if there is a configuration error, that isn't yet handled by this module).    
If you managed to kill this module, fell free to contact me (with your log, you configuration and a description, of what you did to make FHEM unresponsible).

## Credits
I'd like to thank the guys from the home-assistant.io community, they already did some reverse-engineering of the protocol, which helped me implementing the protocol.   
https://community.home-assistant.io/t/ikea-tradfri-gateway-zigbee/14788/18

## Contact me

Feel free to send me an email, if you've any questions or problems: <kappelt.peter@gmail.com>