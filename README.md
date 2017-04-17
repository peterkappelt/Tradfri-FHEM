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
* Get the ID's of all devices that are connected to the gateway

## What this module can not do
These points will be implemented later:
* Set the color temperature of a bulb that is able to do that
* Pair new devices
* Read information from the bulb, like the current brightness, and react to it
* Lighting Groups: control them, get information about the connected devices

## Getting started
You need to do as follows in order to control a bulb:
### 1. Declare the Gateway-Connection

* Define a new device in you FHEM setup: `define TradfriGW TradfriGateway <Gateway-IP> <Gateway-Secret-Key>`.  
* You can use the gateway's IP address or its DNS name
* You can find the Secret Key on the bottom side of your gateway. It is marked as the "Security Code".
* Save your config by running the `save` command in FHEM
### 2. Get the addresses of the conected device
* Get the list of devices: `get TradfriGW deviceList`. It will return something like that:  
   ```
   - 65536
   - 65537
   - 65538
   ```   
   In my setup, there are three devices: Two bulbs and one control unit.  
   Currently, this command doesn't return the type of the devices. We have to find it out empirically in the next step. As far as I've tested, the addresses are asigned with incrementing numbers, so the first address is usually the controller device.

### 3. Define a new device
* Define a new device, with one of the adresses you've just found out: `define Bulb1 TradfriDevice 65537`
* Check, if the gateway device was asigned correctly as the IODev
* Find out the device type.   
   Run `get Bulb1 deviceInfo`. Just close the pop-up window.
   There should be a new reading, called "type". For my bulb, it is "TRADFRI bulb E27 opal 1000lm".  
   This way you can find out, whether this device is a bulb or a controller device.  
* You can now run commands:  
   `set Bulb1 on` will turn the lamp on  
   `set Bulb1 off` will turn the lamp off  
   `set Bulb1 dimvalue x` will set the lamp's brightness, where x is between 0 and 254 

## What to do, if my FHEM isn't responding anymore?
Sorry, the module isn't really stable yet.
Probably, the process coap-client has an issue. You can find out the process id on the command line: `ps -aux | grep coap-client`. Once you got the process id, you can kill it `sudo kill process-id`   
  
I'd appreciate a short crash report, with the relevant part of the FHEM log file and the output of `ps -aux | grep coap-client` (before killing this process)

## Credits
I'd like to thank the guys from the home-assistant.io community, they already did some reverse-engineering of the protocol, which helped me implementing the protocol.   
https://community.home-assistant.io/t/ikea-tradfri-gateway-zigbee/14788/18

## Contact me

Feel free to send me an email, if you've any questions or problems: <kappelt.peter@gmail.com>