# RP-WD03-SD-backup-tool

Backup SD-card from your camera to USB on the ravpower filehub RP-WD03

The Ravpower Filehub wd-03 already has a backup function, but it does not really meet my requirements:

- Start backup without opening the app
- Synchronize only new images from my camera sd-card
- Move images that have been deleted from the sd-card to a separate folder (trashcan) on the usb stick

I recently bought the RP-WD009, which has a dedicated back-up button. The ravpower backup tools unfortunately still copies the entire sd-card every time you backup. My modification also works on my RP-WD009 and I would love to trigger it with the backup-key but have not yet found a way to accomplish that. It will work the same as on the RP-WD03.
Development of this backup-tool started on the verbatim mediashare wireless. It will probably also work on that, but i don't have it anymore to test.

Both the RP-WD03 and the RP-WD009 are excelent devices. Great build quality and support. 

**what will this tool do?**

Well…uhm… the above ;-)

I have been using this method many times over the last few years without any issues and am happy to share it … AS IS! I will accept no responsibility or liability for it. Try it, test how it works and decide if you want te keep it.

**Install**

Just put the files on a sdcard or usb stick and insert into the filehub. Wait until its done blinking.
Your filehub is now prepared to automatically (intelligently) backup sd cards to usb sticks. You no longer need the installation files. The installation is saved to nvram of the filehub and will survive a reboot.

**Usage**

Prepare a usb stick by creating a directory `sd_autobackup` on it

Insert both the sd-card and the usb stick into the filehub
The filehub will start syncing the files, flashing some leds while it is busy

A cardID.txt file containing a random uuid will be created on the sd-card, so the backup tool will recognize the same card on future syncs. That means your sd-card can not be read-only.

When it’s done you should power doen the filehub before removing the card and stick. Otherwise they will not be properly dismounted and you risk data loss.

**Uninstalling**

Simply reset the filehub to factory settings using the tiny reset button or the app. The modifications, that are stored in nvram, will be gone.

**extra**

Have a look at the `EnterRouterMode` if you uncomment the section that enables telnet then the installation procedure will also enable telnet. Use with caution: it will use the default username (root) and possword (20080826) set by the manufacturer. 
