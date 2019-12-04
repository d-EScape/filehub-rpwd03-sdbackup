#!/bin/sh

########################################################################
# 
#  !!This is not a bullit-proof solution! No guaranties!!
#  Having said that; it works pretty well for me...
#  Using rsync would be saver, but even if you can get rsync ported to
#  your platform it will need a lot of resources, that may not be
#  available.
#
#  This is a simple directory synchronization utility for platforms with very little RAM
#  and limited operating systems, like travel routers.
#  It can be used in the field to backup sd cards to a usb stick,
#  without the need to connect a laptop/tablet/phone etc.
#  Every sd card will be backed op in a separate directory, and only
#  new files are copied the next time this sync is run on the same card! :-D
#  deleted files will be placed in a @Trashcan directory.
#  Minimal RAM usage by using files to save file-lists and compare source and target.
#  A little more wear on the target drive is negligible compared to the actual 
#  data copied.
#
#  Install to ravpower RD-WD03:
#  Edit the existing /etc/udev/script/add_usb_storage.sh script
#  to start this tool with SDcard as source and USB as target.
#  e.g. add /etc/udev/script/cpsync.sh /data/UsbDisk1/Volume1 /data/UsbDisk2/Volume1
#  to the end of the original script. Commit modified /etc to flash after succesful testrun.
#
#  This script will very likely need modification to run on other platforms!
#  Especially the led notification is dependent on hardware and firmware.
#
#  EScape
#  Version 2018
#
#########################################################################

#Functions for led control on the ravpower RP-WD03. Modify these functions for specific hardware and firmware.
leds_reset () {
        # blink wifiled while busy. Back to normal after succes. Statusled keeps blinking after failure.      
        /usr/sbin/pioctl internet 3                                                                           
        /usr/sbin/pioctl status 3                                                                             
        /usr/sbin/pioctl wifi 3
        /usr/sbin/pioctl internet 1                                                                           
        /usr/sbin/pioctl status 1                                                                             
        /usr/sbin/pioctl wifi 1           
}   

leds_active () {
	# blink wifiled while busy. Back to normal after succes. Statusled keeps blinking after failure.
	leds_reset
	/usr/sbin/pioctl internet 2 
	/usr/sbin/pioctl status 2
}

leds_done () {
	# blink wifiled while busy. Back to normal after succes. Statusled keeps blinking after failure.
	leds_reset
	/usr/sbin/pioctl internet 0 
}

leds_error () {
	# blink wifiled while busy. Back to normal after succes. Statusled keeps blinking after failure.
	leds_reset
	/usr/sbin/pioctl status 2
}

#Cleanup when script exits
cleanexit () {
	filepid=$(cat "/tmp/cpsync.pid")
	if [ $filepid -eq $$ ]; then
		rm /tmp/cpsync.pid
		[ -f /var/lock/wifidg ] && rm /var/lock/wifidg
		sync
	fi
	exit
}


#Exit if no valid source and target is found
if [ "$1" = "" ] || [ "$2" = "" ]; then
	echo Usage: cpsync sourcedir targetdir
	exit
fi

sourcepath="$1"
targetpath="$2"

if [ ! -d "$sourcepath" ]; then
	echo $sourcepath "(source) does not exist"
	exit
fi
if [ ! -d "$targetpath" ]; then       
        echo $targetpath "(target) does not exist"
        exit                                            
fi

#Exit when another backup is still running.                                                                   
if [ -f /tmp/cpsync.pid ]; then                                                                               
        echo Another Sync job is running ... exiting                           
        exit                                                                                                  
fi
#Create pid file                                                                          
echo $$ > /tmp/cpsync.pid

trap cleanexit EXIT   

#Perform an extra check to work-around rapower triggering multiple usb_add scripts
thissync=$(date +%s)
if [ -f /tmp/cpsync.last ]; then
	lastsync=$(cat "/tmp/cpsync.last")
	delta=$((thissync-lastsync))
	if [ $delta -lt 20 ]; then
		echo Can not sync again within 20 seconds to prevent multiple usb triggers
		exit
	fi
fi

# blink wifiled while busy. Back to normal after succes. Statusled keeps blinking after failure.                                                                
# wifidg file stops OS from changing the leds. 
# Completion signal is questionable, since control is handed back to OS after this program ends.
touch /var/lock/wifidg                                                                                                                           
leds_active 
echo $thissync > "/tmp/cpsync.last"

#Alle systems GO!

#Set the source location and find or create unique ID for this source
sourcepath=$(readlink -f "$sourcepath")
uuid_file="$sourcepath/cardID.txt"
if [ -e "$uuid_file" ]; then
	sd_uuid=$(cat "$uuid_file")
else
	if [ -f /proc/sys/kernel/random/uuid ]; then
		sd_uuid=`cat /proc/sys/kernel/random/uuid`
	else
		sd_uuid="unknown"
	fi
	echo "$sd_uuid" > "$uuid_file"
fi
#Set the target location to include the ID
targetpath=$(readlink -f "$targetpath")/$sd_uuid

#Create a working directory for this programm in the target
workdir="$targetpath/@Syncfiles"
if [ ! -d "$workdir" ]; then
	mkdir -p "$workdir"
fi

echo Working directory is: $workdir
tempfile="$workdir/synctemp.sd.txt"
sourcesfile="$workdir/syncsources.sd.txt"
targetsfile="$workdir/synctargets.sd.txt"
archivepath="$targetpath/@Trashcan"
todofile="$workdir/syncactions.txt"
deletefile="$workdir/syncdeletes.txt"
dirfile="$workdir/syncdirs.txt"
logfile="$workdir/synclog.txt"


echo starting
# Set counters
numdirs=0
numfiles=0
totfiles=0
numdel=0
numerr=0
nummverr=0

# Create support files or purge existing ones 
[ -f "$logfile" ] && rm "$logfile"
[ -f "$tempfile" ] && rm "$tempfile" 
# Put header in files otherwise grep compare fails
echo Comparefile > "$sourcesfile"
echo Comparefile > "$targetsfile"

echo Sync from $sourcepath to $targetpath started >> $logfile

find "$sourcepath" -type d ! -path "$sourcepath/Share" ! -path "*/.*" >> "$tempfile"
#format output by adding the full path and add a prefix to stop grep from matching substrings
while read f
do
	echo ">>>"${f#${sourcepath}} >> "$dirfile"
done <"$tempfile"
rm $tempfile

#Get all filenames from source, but ignore minidlna Share directory and hidden files and directories.
find "$sourcepath" -type f ! -path "$sourcepath/Share/*" ! -path "*/.*" >> "$tempfile"

#format output by adding the full path and add a prefix to stop grep from matching substrings
while read f
do
	echo ">>>"${f#${sourcepath}} >> "$sourcesfile"
done <"$tempfile"
rm $tempfile

#Get all filenames from source, but ignore special folders used by this programm and hidden files and directories.
find "$targetpath" -type f ! -path "*/.*" ! -path "$workdir*" ! -path "$archivepath*" >> "$tempfile"

#format output by adding the full path and add a prefix to stop grep from matching substrings
while read f
do
	echo ">>>"${f#${targetpath}} >> "$targetsfile"
done <"$tempfile"

#Got sources and targets.... now find differences
/bin/grep -v -f "$targetsfile" "$sourcesfile" > "$todofile"
/bin/grep -v -f "$sourcesfile" "$targetsfile" > "$deletefile"

echo Files in target: $(wc -l "$targetsfile") >> $logfile
echo Files in source: $(wc -l "$sourcesfile") >> $logfile
echo Files to be copied: $(wc -l "$todofile") >> $logfile
echo Files to be archived: $(wc -l "$deletefile") >> $logfile

#start measuring the time and disk usage to calculate performance of file operations
starttime=$(date +%s)  
startdiskusg=$(df -m "$targetpath" | grep -vE '^Filesystem' | awk '{ print $3 }')

#Create directories that are in source but not in target.
while read f
do
	#first remove the prefix needed to stop grep from matching substrings
	makepath=$targetpath${f:3}
	if [ ! -d "$makepath" ]; then
		mkdir -p "$makepath"
		numdirs=$((numdirs+1))                
		err=$?
		if [ $err != 0 ]; then
			echo "Failed! error $err: $makepath could not be created" >> $logfile
			numerr=$((numerr+1))
		else
			echo Succesfully created "$makepath" >> $logfile
			numfiles=$((numfiles+1))
		fi	
	fi
done <$dirfile


#Copy files that are in source but not in target. Will not overwrite any existing file. Not even if target is older or other file with same name.
while read f
do
	#first remove the prefix needed to stop grep from matching substrings
	f=${f:3}                              	
	cp "$sourcepath$f" "$targetpath$f"
	err=$?
	if [ $err != 0 ]; then
		echo "Failed! error $err: $sourcepath$f could not be copied" >> $logfile
		numerr=$((numerr+1))
	else
		echo Succesfully copied "$sourcepath$f" >> $logfile
		numfiles=$((numfiles+1))
	fi	
done <$todofile

#Move files  that are nog longer in source from target to @Trashcan. Empty directories wil not be removed!                                                                                
while read f                                                                                   
do
	#first remove the prefix needed to stop grep from matching substrings
	f=${f:3}                                                                                             
	echo Moving $f to @Trashcan                                                        
	makepath="$archivepath${f%/*}"                                                            
	if [ ! -d "$makepath" ]; then                                                            
		 mkdir -p "$makepath"                                                             
	fi                                                                                     
	mv "$targetpath$f" "$archivepath$f"                                                     
	err=$?
	if [ $err != 0 ]; then
		 echo "Failed! error $err moving $f to @Trashcan" >> $logfile                                                                   
		 nummverr=$((nummverr+1))                                                           
	else 
		 echo Moved $f to @Trashcan >> $logfile
		 numdel=$((numdel+1))
	fi     
done <$deletefile

#calculate time taken by actual sync                                           
endtime=$(date +%s)
timespend=$((endtime-starttime)) 
#calculate changes en speed in MB
enddiskusg=$(df -m "$targetpath" | grep -vE '^Filesystem' | awk '{ print $3 }') 
diskusgdelta=$((enddiskusg-startdiskusg))
[ $timespend -gt 0 ] && copyspeed=$((diskusgdelta/timespend)) || copyspeed="--"

#create log
echo Done creating $numdirs Directories en copying $numfiles Files. $numdel files where moved to @Trashcan. >> $logfile          
echo $numerr errors occurred while copying files. $nummverr errors while moving files to @Trashcan. >> $logfile
echo Adding $diskusgdelta MB took: $timespend seconds at an avarage of $copyspeed MB/s. >> $logfile
echo $(df -m "$targetpath" | grep -vE '^Filesystem' | awk '{ print $2 }') MB of space remaining on target drive. >> $logfile

#signal success or failure through leds and eject source if parameter given
if [ $((numerr+nummverr)) -eq 0  ]; then
	leds_done
	#Need a better way to umount. This does not remove mount directory. 
	if [ "$3" == "eject" ]; then
		mountpoint=$(df "$sourcepath" | tail -1 | awk '{ print $6 }')
		/usr/sbin/umount2 "$mountpoint"
		[ $? != 0 ] && leds_error
	fi
else
	leds_error
fi
#cleanup support files that where used to reduce the ram needed
rm "$tempfile"
rm "$sourcesfile"
rm "$targetsfile"
rm "$todofile"
rm "$deletefile"
rm "$dirfile"
