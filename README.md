```
┌─[ sl-firstboot ]────────────────────────────────────────────────────────────┐
│     ┬─────┐ ─┬─ ┬────┐ ┌────┐ ┌──┬──┐   ┬─────┐ ┌─────┐ ┌─────┐ ┌──┬──┐     │
│     ├────    │  ├───┬┘ └────┐    │      ├─────┤ │     │ │     │    │        │
│     ┴       ─┴─ ┴   ┴  └────┘    ┴      ┴─────┘ └─────┘ └─────┘    ┴        │
├───────────────────────────────────[ and ]───────────────────────────────────┤
│  ┬─────┐ ─┬─ ┬────┐ ┌────┐ ┌──┬──┐  ┌─────┐ ┌──┬──┐ ┌─────┐ ┬────┐ ┌──┬──┐  │
│  ├────    │  ├───┬┘ └────┐    │     └─────┐    │    ├─────┤ ├───┬┘    │     │
│  ┴       ─┴─ ┴   ┴  └────┘    ┴     └─────┘    ┴    └     ┘ ┴   ┴     ┴     │
└─────────────────────────────────────────────────────────────[ by SkyLined ]─┘
```
sl-firstboot is a set of batch scripts that allow you to modify a Raspberry Pi
OS image so that it runs a bash script during or after the first boot of the
image. It is designed to be used on a Windows machine.

There are two batch scripts, one to inject a bash script _during_ the first
boot, when the system is not yet fully up and running, and one to inject a bash
script _after_ the first boot, once the system is up and a network connection
has been established. The first is useful if you want to make low-level changes
early on, so these can take effect during boot. The later is useful if you want
to make higher-level changes that required interacting with components not
available until the system is fully up and running. *In most cases, this second
option is what you want.*


# sl-firstboot
sl-firstboot allows you to run a bash script _during_ the first boot of a
Raspberry Pi image through minimal changes to the FAT32 boot partition of the
image.

When your script is run, the system is still booting up and many things are not
available yet. Your script should be aware of this; in most cases, you will want
to use sl-firststart to avoid this.


# sl-firststart
sl-firststart allows you to run a bash script _after_ the first boot of a
Raspberry Pi image through minimal changes to the FAT32 boot partition of the
image. The script is run through a systemd service after network connection has
been established.

When your script is run, the system is fully started and everything should be
available, including network connectivity.


# How to use
On a Windows machine, insert a USB stick or SD card with a Raspberry Pi image
that you want to run your script on. On the same machine, have a copy of your
script ready. Then run one of these command:
```
sl-firstboot.cmd <USB drive letter> <path\to\your\script>
sl-firststart.cmd <USB drive letter> <path\to\your\script>
```
For example, if you want the script `my-boot-init-script.sh` in the current
folder installed on a USB stick in the `D:` drive, you would use this command:
```
sl-firstboot.cmd D: my-boot-init-script.sh
```
After running this command, the image will have been updated and it is ready to
use on a Raspberry Pi.


## dos2unix
These tools can use *dos2unix.exe* to automatically make sure all script files
have unix-style line-breaks. This is not required, but you will have to make
sure your scripts do not using Windows-style line-breaks.

You can download dos2unix from [the dos2unix webpage](https://dos2unix.sourceforge.io).
See _requirements_ below for more details on how to make sure it gets used.


# How it works

## sl-firstboot
sl-firstboot copies an initialization script (`sl-firstboot-init`) onto the
FAT32 boot partition of the Raspberry Pi OS image. It also copies your script to
the same partition (as `sl-firstboot-payload`). It then modifies the file
`cmdline.txt` on this partition to change the `init=` value, and add a command
there to run the initialization script when the device boots.

When the Raspberry Pi boots up it will:
  1. mount the boot partitions as read-write,
  2. run `sl-firstboot-init`,
  3. unmount the boot partition,
  4. reboot the system.

When `sl-firstboot-init` runs, it will:
  1. run the payload script,
  2. if this fails, start `/bin/bash` and exit, otherwise
  3. revert the changes made to `cmdline.txt` on the boot partition,
  4. delete the initialization script from the boot partition,
  5. delete the payload script from the boot partition,

If the payload script runs successfully, all changes made to the image by
sl-firstboot will be reverted. Any changes made to the image by the payload
script will remain. The system will reboot and continue to boot normally.

If the payload script fails, a root shell will be started to allow you to debug
any issues. The boot partition will not be modified; the next time the system is
booted the `sl-firstboot-init` script will be run again, and with it your
payload.

## sl-firststart
sl-firststart uses sl-firstboot to copy an initialization script
(`sl-firststart-init`, renamed to `sl-firstboot-payload`) onto the boot
partition of the USB drive. It also copies your script to the same partition as
`sl-firststart-payload`.

When the Raspberry Pi is first booted, sl-firstboot causes the
`sl-firstboot-payload` script (which is a copy of the `sl-firststart-init`
script) to be run.
When `sl-firstboot-payload` runs, it will:
  1. move `sl-firststart-payload` from the boot partition to `/usr/lib/`
  2. create an `sl-firststart` service,
  3. enable the `sl-firststart` service,
  4. disable the `userconfig` service (_see below_).

After this, all changes made by sl-firststart/sl-firstboot to the boot partition
will be reverted and the system reboots. The root partition will have the
`sl-firststart` service and the `sl-firststart-payload` script added. The
system will continue with booting normally. When the system has been booted and
network connectivity is established, the `sl-firststart` service starts.

The `sl-firststart` service will:
  1. run `/usr/lib/sl-firststart-payload`,
  2. if this fails, start `/bin/bash` and exit, otherwise
  3. delete `/usr/lib/sl-firststart-payload`,
  4. disable the `sl-firststart` service,
  5. delete the `sl-firststart` service.

If the payload script fails, the remaining steps are not executed. This means
the payload script will continue to be run every time the system boots. Once the
payload script succeeds, the service and script are removed and will no longer
be executed on start up.


### userconfig.service
The `userconfig.service` is disabled by sl-firststart as this is the normal
first start script for Raspbian OS, i.e. the script which asks you to provide a
username and password once your Raspberry Pi starts for the first time. The
payload script run through sl-firststart is expected to replace this script,
making it obsolete and potentially disruptive, as it uses the same TTY.


# dos2unix
sl-firstboot can *dos2unix.exe* to copy files to the USB drive and make sure
the files have unix-style line-breaks. You can download dos2unix from
[this page](https://dos2unix.sourceforge.io/#DOS2UNIX) by scrolling down to
the bottom of the page and looking under the _Ready-to-run-binaries_ heading.
There you will find a _Windows_ section with links to download zip files.

After downloading the right zip file for your system, extract the files from
the zip and make sure to either add the path of the extracted `bin` folder to
the PATH environment variable, or have the `dos2unix.exe` file in the current
working directory before you use these tools.

The tools will let you know if dos2unix is used and warn you if dos2unix cannot
be found.


# Questions and Answers
Q: Does my script need to have unix-style line-breaks?
A: No, when the script is copied to the image, line-breaks are automatically
   converted