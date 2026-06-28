# Wire-Pod

`wire-pod` is fully-featured server software for the Anki (now Digital Dream Labs) [Vector](https://web.archive.org/web/20190417120536if_/https://www.anki.com/en-us/vector) robot. It was created thanks to Digital Dream Labs' [open-sourced code](https://github.com/digital-dream-labs/chipper).

It allows voice commands to work with any Vector 1.0 or 2.0 for no fee, including regular production robots.

## Docker based Installation

This requires the host to posess either the hostname of escapepod.local or have an mDNS configuration for it

On a Debian based system you can setup an mDNS alias as follows:

install avahi-utils
sudo apt install avahi-utils
create a systemd service config
# /etc/systemd/system/avahi-alias@.service
[Unit]
Description=Publish %I as alias for %H.local via mdns

[Service]
Type=simple
ExecStart=/bin/bash -c "/usr/bin/avahi-publish -a -R %I $(avahi-resolve -4 -n %H.local | cut -f 2)"

[Install]
WantedBy=multi-user.target
Start the service and enable it's persistence
sudo systemctl enable --now avahi-alias@escapepod.local.service
Now you can proceed with the docker portion.

On the device you would like to install wire-pod on, make sure you have docker installed. This can be done with the command sudo apt install docker-ce for linux.
Verify if the docker engine is working with the command sudo service docker status
Run this command to create and download the wire-pod application
docker compose up -d -f https://raw.githubusercontent.com/kercre123/wire-pod/main/compose.yaml
With a device on the same network as wire-pod, open a browser and head to the configuration page. http://your_ip:8080/. In that page, follow the instructions. Wire-pod should then be set up!
Continue on to "Authenticate the bot with wire-pod", near the bottom of this page.

## Wiki

Check out the [wiki](https://github.com/kercre123/wire-pod/wiki) for more information on what wire-pod is, a guide on how to install wire-pod, troubleshooting, how to develop for it, and for some generally helpful tips.

## Donate

If you want to :P

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/kercre123)

## Credits

- [Digital Dream Labs](https://github.com/digital-dream-labs) for open sourcing chipper and creating escape pod (which made this possible)
- [bliteknight](https://github.com/bliteknight) for making wire-pod more accessible with his easy-to-use pre-setup Linux boxes
- [dietb](https://github.com/dietb) for rewriting chipper and giving tips
- [fforchino](https://github.com/fforchino) for adding many features such as localization and multilanguage, and for helping out
- [xanathon](https://github.com/xanathon) for the publicity and web interface help
- Anyone who has opened an issue and/or created a pull request for wire-pod
