#
# Copyright (C) 2013 The Android-x86 Open Source Project
#
# License: GNU Public License v2 or later
#

function set_property()
{
	# this must be run before post-fs stage
	echo $1=$2 >> /x86.prop
}

function init_misc()
{
	# a hack for USB modem
	lsusb | grep 1a8d:1000 && eject

	# in case no cpu governor driver autoloads
	[ -d /sys/devices/system/cpu/cpu0/cpufreq ] || modprobe acpi-cpufreq

	case "$PRODUCT" in
		T10*TA)
			;;
		*)
			;;
	esac
}

function init_hal_audio()
{
	case "$PRODUCT" in
		VirtualBox*|Bochs*)
			[ -d /proc/asound/card0 ] || modprobe snd-sb16 isapnp=0 irq=5
			;;
		*)
			;;
	esac
}

function init_hal_bluetooth()
{
	for r in /sys/class/rfkill/*; do
		type=$(cat $r/type)
		[ "$type" = "wlan" -o "$type" = "bluetooth" ] && echo 1 > $r/state
	done

	# these modules are incompatible with bluedroid
	rmmod ath3k
	rmmod btusb
	rmmod bluetooth
	set_property ro.rfkilldisabled 1
}

function init_hal_camera()
{
	[ -c /dev/video0 ] || modprobe vivi
}

function init_hal_gps()
{
	# TODO
	return
}

function set_drm_mode()
{
	case "$PRODUCT" in
		ET1602*)
			drm_mode=1366x768
			;;
		*)
			;;
	esac

	[ -n "$drm_mode" ] && set_property debug.drm.mode.force $drm_mode
}

function init_uvesafb()
{
	case "$PRODUCT" in
		*Q550)
			UVESA_MODE=${UVESA_MODE:-1280x800}
			;;
		ET2002*)
			UVESA_MODE=${UVESA_MODE:-1600x900}
			;;
		T91*)
			UVESA_MODE=${UVESA_MODE:-1024x600}
			;;
		VirtualBox*|Bochs*)
			UVESA_MODE=${UVESA_MODE:-1024x768}
			;;
		*)
			;;
	esac

	modprobe uvesafb mode_option=${UVESA_MODE:-800x600}-16 ${UVESA_OPTION:-mtrr=3 scroll=redraw}
}

function init_hal_gralloc()
{
	case "$(cat /proc/fb | head -1)" in
		0*inteldrmfb|0*radeondrmfb|0*nouveaufb)
			set_property hal.gralloc drm
			set_drm_mode
			set_property debug.egl.trace error
			;;
		0*svgadrmfb)
			;;
		"")
			init_uvesafb
			;&
		0*)
			[ "$HWACCEL" = "1" ] || set_property debug.egl.hw 0
			;;
	esac
}

function init_hal_hwcomposer()
{
	# TODO
	return
}

function init_hal_lights()
{
	chown 1000.1000 /sys/class/backlight/*/brightness
}

function init_hal_power()
{
	for p in /sys/class/rtc/*; do
		echo disabled > $p/device/power/wakeup
	done

	# TODO
	case "$PRODUCT" in
		*)
			;;
	esac
}

function init_hal_sensors()
{
	case "$(cat $DMIPATH/uevent)" in
		*Lucid-MWE*)
			set_property ro.ignore_atkbd 1
			set_property hal.sensors hdaps
			;;
		*ICONIA*W5*)
			set_property hal.sensors w500
			;;
		*S10-3t*)
			set_property hal.sensors s103t
			;;
		*Inagua*)
			#setkeycodes 0x62 29
			#setkeycodes 0x74 56
			set_property ro.ignore_atkbd 1
			set_property hal.sensors kbd
			set_property hal.sensors.kbd.type 2
			;;
		*TEGA*|*2010:svnIntel:*)
			set_property ro.ignore_atkbd 1
			set_property hal.sensors kbd
			set_property hal.sensors.kbd.type 1
			io_switch 0x0 0x1
			setkeycodes 0x6d 125
			;;
		*DLI*)
			set_property ro.ignore_atkbd 1
			set_property hal.sensors kbd
			set_property hal.sensors.kbd.type 1
			setkeycodes 0x64 1
			setkeycodes 0x65 172
			setkeycodes 0x66 127
			setkeycodes 0x67 116
			setkeycodes 0x68 114
			setkeycodes 0x69 115
			setkeycodes 0x6c 114
			setkeycodes 0x6d 115
			;;
		*tx2*)
			setkeycodes 0xb1 138
			setkeycodes 0x8a 152
			set_property hal.sensors kbd
			set_property hal.sensors.kbd.type 6
			set_property poweroff.doubleclick 0
			set_property qemu.hw.mainkeys 1
			;;
		*MS-N0E1*)
			set_property ro.ignore_atkbd 1
			setkeycodes 0xa5 125
			setkeycodes 0xa7 1
			setkeycodes 0xe3 142
			;;
		*Aspire1*25*)
			modprobe lis3lv02d_i2c
			set_property hal.sensors hdaps
			echo -n "enabled" > /sys/class/thermal/thermal_zone0/mode
			;;
		*ThinkPad*Tablet*)
			modprobe hdaps
			set_property hal.sensors hdaps
			;;
		*)
			set_property hal.sensors kbd
			;;
	esac

	# has sensor-hub?
	for i in /sys/bus/iio/devices/iio:device?; do
		if [ -e $i/in_accel_scale ]; then
			busybox chown -R 1000.1000 /sys/bus/iio/devices/iio:device?/
			set_property hal.sensors hsb
			break
		fi
	done
}

function create_pointercal()
{
	if [ ! -e /data/misc/tscal/pointercal ]; then
		mkdir -p /data/misc/tscal
		touch /data/misc/tscal/pointercal
		chown 1000.1000 /data/misc/tscal /data/misc/tscal/*
		chmod 775 /data/misc/tscal
		chmod 664 /data/misc/tscal/pointercal
	fi
}

function init_tscal()
{
	case "$PRODUCT" in
		T91|T101|ET2002|945GSE-ITE8712|CF-19[CDYFGKLP]*)
			create_pointercal
			return
			;;
		*)
			;;
	esac

	for usbts in $(lsusb | awk '{ print $6 }'); do
		case "$usbts" in
			0596:0001|0eef:0001)
				create_pointercal
				return
				;;
			*)
				;;
		esac
	done
}

function init_ril()
{
	case "$(cat $DMIPATH/uevent)" in
		*TEGA*|*2010:svnIntel:*|*Lucid-MWE*)
			set_property rild.libpath /system/lib/libhuaweigeneric-ril.so
			set_property rild.libargs "-d /dev/ttyUSB2 -v /dev/ttyUSB1"
			;;
		*)
			set_property rild.libpath /system/lib/libreference-ril.so
			set_property rild.libargs "-d /dev/ttyUSB2"
			;;
	esac
}

function init_cpu_governor()
{
	governor=$(getprop cpu.governor)

	[ $governor ] && {
		for cpu in $(ls -d /sys/devices/system/cpu/cpu?); do
			echo $governor > $cpu/cpufreq/scaling_governor || return 1
		done
	}
}

function do_init()
{
	init_misc
	init_hal_audio
	init_hal_bluetooth
	init_hal_camera
	init_hal_gps
	init_hal_gralloc
	init_hal_hwcomposer
	init_hal_lights
	init_hal_power
	init_hal_sensors
	init_tscal
	init_ril
	chmod 640 /x86.prop
	post_init
}

function do_netconsole()
{
	modprobe netconsole netconsole="@/,@$(getprop dhcp.eth0.gateway)/"
}

function do_bootcomplete()
{
	init_cpu_governor

	[ -z "$(getprop persist.sys.root_access)" ] && setprop persist.sys.root_access 3

	# FIXME: autosleep works better on i965?
	[ "$(getprop debug.mesa.driver)" = "i965" ] && setprop debug.autosleep 1

	lsmod | grep -e brcmfmac && setprop wlan.no-unload-driver 1

	for bt in $(lsusb -v | awk ' /Class:.E0/ { print $9 } '); do
		chown 1002.1002 $bt && chmod 660 $bt
	done
#	am force-stop com.android.bluetooth

	case "$PRODUCT" in
		1866???|1867???|1869???) # ThinkPad X41 Tablet
			start tablet-mode
			start wacom-input
			setkeycodes 0x6d 115
			setkeycodes 0x6e 114
			setkeycodes 0x69 28
			setkeycodes 0x6b 158
			setkeycodes 0x68 172
			setkeycodes 0x6c 127
			setkeycodes 0x67 217
			;;
		6363???|6364???|6366???) # ThinkPad X60 Tablet
			;&
		7762???|7763???|7767???) # ThinkPad X61 Tablet
			start tablet-mode
			start wacom-input
			setkeycodes 0x6d 115
			setkeycodes 0x6e 114
			setkeycodes 0x69 28
			setkeycodes 0x6b 158
			setkeycodes 0x68 172
			setkeycodes 0x6c 127
			setkeycodes 0x67 217
			;;
		7448???|7449???|7450???|7453???) # ThinkPad X200 Tablet
			start tablet-mode
			start inputattach
			setkeycodes 0xe012 158
			setkeycodes 0x66 172
			setkeycodes 0x6b 127
			;;
		*)
			;;
	esac

	for c in $(grep '\[.*\]' /proc/asound/cards | awk '{print $1}'); do
		f=/system/etc/alsa/$(cat /proc/asound/card$c/id).state
		if [ -e $f ]; then
			alsa_ctl -f $f restore $c
		else
			alsa_ctl init $c
			alsa_amixer -c $c set Master on
			alsa_amixer -c $c set Master 100%
			alsa_amixer -c $c set Headphone on
			alsa_amixer -c $c set Headphone 100%
			alsa_amixer -c $c set Speaker 100%
			alsa_amixer -c $c set Capture 100%
			alsa_amixer -c $c set Capture cap
			alsa_amixer -c $c set PCM 100 unmute
			alsa_amixer -c $c set 'Mic Boost' 3
			alsa_amixer -c $c set 'Internal Mic Boost' 3
		fi
	done
}

PATH=/system/bin:/system/xbin

DMIPATH=/sys/class/dmi/id
BOARD=$(cat $DMIPATH/board_name)
PRODUCT=$(cat $DMIPATH/product_name)

# import cmdline variables
for c in `cat /proc/cmdline`; do
	case $c in
		androidboot.hardware=*)
			;;
		*=*)
			eval $c
			;;
	esac
done

[ -n "$DEBUG" ] && set -x || exec &> /dev/null

# import the vendor specific script
hw_sh=/vendor/etc/init.sh
[ -e $hw_sh ] && source $hw_sh

case "$1" in
	netconsole)
		[ -n "$DEBUG" ] && do_netconsole
		;;
	bootcomplete)
		do_bootcomplete
		;;
	init|"")
		do_init
		;;
esac

return 0
