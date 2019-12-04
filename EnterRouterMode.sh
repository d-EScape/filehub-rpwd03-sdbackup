if [ -e /tmp/autoinstalllock ]; then
	exit
fi

touch /tmp/autoinstalllock

mod=0
scriptdir=${0%/*}

# to enable root telnet access to ravpower filehub rp-wd03
# uncomment the section below
# if ! [ -e /etc/telnetflag ]; then
# 	/usr/sbin/telnetd &
# 	touch /etc/telnetflag
# 	mod=1
# else
# 	echo Telnet already active
# fi

#script klaarzetten
if ! [ -e /etc/udev/script/cpsync.sh ]; then
	cp $scriptdir/cpsync.sh /etc/udev/script/
	mod=1
else
	echo cpsync.sh already available
fi
#extra opdracht toevoegen aan bestaande usb startscript:

if ! grep -q '#CPSYNCMOD' /etc/udev/script/add_usb_storage.sh; then
	beforeline='echo \"$1: Exit: Normal\" >> \/tmp\/usb_add_info'
	position=$(sed -n "/$beforeline/=" /etc/udev/script/add_usb_storage.sh | tail -n1) 
	position=$((position-1))
	sed -i "$position r $scriptdir/patch.ins" /etc/udev/script/add_usb_storage.sh
	mod=1
else
	echo USB mounting already includes cpsync call
fi

if [ $mod -ne '0' ]; then
	#if anything changed it needs to be written to nvram
	echo Writing etc to flash
	/usr/sbin/etc_tools p
else
	echo Nothing changed
fi

sync
rm -f /tmp/autoinstalllock