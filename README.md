# FHEM Trådfri Module

This is a small extension module for the FHEM Home-Control software. It enables connectivity to an IKEA Trådfri gateway.

## Install to FHEM
Run the following commands to add this repository to your FHEM setup:
```
update add https://raw.githubusercontent.com/peterkappelt/Tradfri-FHEM/master/src/controls_tradfri.txt
update
shutdown restart
```

The shutdown is optional, but I recommend it.  
Since there is no Changelog file and no documentation yet, FHEM will throw some errors during update. Don't worry about them.

## Prerequisites

You need to have an IKEA Trådfri Bulb or Panel, a Control-Device (e.g. the Dimmer) and the Gateway.  
The gateway has to be set-up with the App, the control device and the bulbs need to be paired.  
__Caution__: Do not make the same mistake I've made. You can __not__ just buy a bulb and a gateway. You need a control device, like the round dimmer, too!

The JSON-Perl packages are required.

Furthermore, you need to install the software "libcoap". You can find its repository here: https://github.com/obgm/libcoap  
This library needs to be built, have a look into its documentation. I've run the following commands:
```
apt-get install libtool

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
* Manage your gateway connection centrally (you've to define the Gateway IP in each device seperately)

## Getting started
You need to do as follows in order to control a bulb:
### 1. Get the addresses of the connected devices
* Define a new device in you FHEM setup: `define temp TradfriDevice a`.  
   A valid device address is not yet necessary, since you don't know any. You can just define something.
* Enter your Gateway IP address or its DNS name as an attribute: `attr temp gatewayIP TradfriGW.int.kappelt.net`  
   Replace it with the IP of your gateway.
* Enter the Gateway Secret as an attribute: `attr temp gatewaySecret Your-Secret`  
   You can find this on a label on the bottom side of your gateway. It is marked as the "Security Code".
* Please note, that you need to enter those parameteres before doing anything else. If you try to run a command without valid values, your setup will likely crash.
* Get the list of devices: `get temp deviceList`. It will return something like that:  
   ```
   65536
   65537
   65538
   ```   
   In my setup, there are three devices: Two bulbs and one gateway.  
   Currently, this command doesn't return the type of the devices. We have to find it out empirically in the next step. Usually, the first number is the Controller Device.
* You can now delete this device.

### 2. Define a new device
* Define a new device, with one of the adresses you've just found out: `define Bulb1 TradfriDevice 65537`
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
  
I'd appreciate a short crash report.

## Credits
I'd like to thank the guys from the home-assistant.io community, they already did some reverse-engineering of the protocol, which helped me implementing the protocol.   
https://community.home-assistant.io/t/ikea-tradfri-gateway-zigbee/14788/18

## Contact me

Feel free to send me an email, if you've any questions or problems: <kappelt.peter@gmail.com>