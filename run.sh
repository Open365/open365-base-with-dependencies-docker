#!/bin/bash

set -u -x

EYEOS_UNIX_USER=${EYEOS_UNIX_USER:-"user"}

SPICE_RES=${SPICE_RES:-"1280x960"}
SPICE_RES_FORMATED=`echo $SPICE_RES | tr x ' '`
SPICE_LOCAL=${SPICE_LOCAL:-"es_ES.UTF-8"}
TIMEZONE=${TIMEZONE:-"Europe/Madrid"}
SPICE_USER=${SPICE_USER:-$EYEOS_UNIX_USER}
SPICE_UID=${SPICE_UID:-"1000"}
SPICE_GID=${SPICE_GID:-"1000"}
SPICE_PASSWD=${SPICE_PASSWD:-"password"}
SPICE_KB=`echo "$SPICE_LOCAL" | awk -F"_" '{print $1}'` 
SUDO=${SUDO:-"NO"}
# USE_BIND_MOUNT_FOR_LIBRARIES: envar that handles how to make accessible
# the seafile libraries in the user space.
# * If not set, we mount the seafile dav volume directly inside the home of the
#   user.
# * If set, we mount the dav volume somewhere in /mnt and bind-mount each
#   library inside the user's home, and remove permissions in the user's home
USE_BIND_MOUNT_FOR_LIBRARIES="${USE_BIND_MOUNT_FOR_LIBRARIES:-}"
if [ "$USE_BIND_MOUNT_FOR_LIBRARIES" = "false" ]
then
	USE_BIND_MOUNT_FOR_LIBRARIES=""
fi


locale-gen $SPICE_LOCAL
echo $TIMEZONE > /etc/timezone
useradd -ms /bin/bash -u $SPICE_UID $SPICE_USER
echo "$SPICE_USER:$SPICE_PASSWD" | chpasswd
sed -i "s|#Option \"SpicePassword\" \"\"|Option \"SpicePassword\" \"$SPICE_PASSWD\"|" /etc/X11/spiceqxl.xorg.conf
unset SPICE_PASSWD
update-locale LANG=$SPICE_LOCAL
sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"$SPICE_KB\"/" /etc/default/keyboard
sed -i "s/SPICE_KB/$SPICE_KB/" /etc/xdg/autostart/keyboard.desktop
sed -i "s/SPICE_RES/$SPICE_RES/" /etc/xdg/autostart/resolution.desktop
if [ "$SUDO" != "NO" ]; then
	sed -i "s/^\(sudo:.*\)/\1$SPICE_USER/" /etc/group
fi

# This is to be able to send the user notification via eyeos-usernotification
if expr "$AMQP_BUS_HOST" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
  amqpHostIp=$AMQP_BUS_HOST
else
  amqpHostIp=$(getent hosts $AMQP_BUS_HOST | awk '{print $1}')
fi

echo "$amqpHostIp rabbit.service.consul" >> /etc/hosts

cd /home/$SPICE_USER

# These should only be copied the first time
if [[ ! -f /home/$SPICE_USER/.eyeosConfigured ]]; then
	cp /root/.gtkrc-2.0 .
	cp /etc/skel/.config/ratpoisonrc .ratpoisonrc
	mkdir .config
	cp -r /etc/skel/.config/* .config/
	mkdir .local
	cp -r /etc/skel/.local/* .local/

	# create other files that will be needed later for some applications,
	# because we are removing write permissions in /home/$SPICE_USER later
	# and if the directories do not exist and cannot be created by the user
	# those applications that need'em may not start correctly
	mkdir -p .cache .dbus .kde

	chown $SPICE_USER /home/$SPICE_USER -R
	chown $SPICE_USER /mnt/eyeos -R

	mkdir -p /home/$SPICE_USER/.kde/share/config
	mkdir -p /home/$SPICE_USER/.kde/share/apps/
	cp -rf /etc/skel/.config/* /home/$SPICE_USER/.kde/share/config/
	cp -rf /etc/skel/.local/share/* /home/$SPICE_USER/.kde/share/apps/
	chown $SPICE_USER /home/$SPICE_USER/.kde -R

	touch /home/$SPICE_USER/.eyeosConfigured
fi

#su $SPICE_USER -c "/usr/bin/Xorg -config /etc/X11/spiceqxl.xorg.conf -logfile  /home/$SPICE_USER/.Xorg.2.log :2 &" 2>/dev/null
if [ -z "$LANG" ]; then
    LANG=en_US.UTF-8
fi
/usr/sbin/locale-gen $LANG

rm /tmp/.X2-lock | true
su $SPICE_USER -c "Xspice --deferred-fps 30 --streaming-video all --jpeg-wan-compression=always --vdagent :2 &"

export DISPLAY=":2"
until xset -q
do
	echo "Waiting for X server to start..."
	sleep 0.1;
done

#set custom resolution
CMD="setcustomresolution $SPICE_RES_FORMATED 59.90"
${CMD}

# Start CUPS service
service cups restart

# Storing env variables of our interest to a readable file
echo "export EYEOS_UNIX_USER=$EYEOS_UNIX_USER" > /tmp/global.env
echo "export BUS_ADDRESS_HOST=$BUS_ADDRESS_HOST" >> /tmp/global.env
echo "export BUS_SUBSCRIPTION=$BUS_SUBSCRIPTION" >> /tmp/global.env
echo "export EYEOS_BUS_MASTER_PASSWD=$EYEOS_BUS_MASTER_PASSWD" >> /tmp/global.env
echo "export EYEOS_BUS_MASTER_USER='$EYEOS_BUS_MASTER_USER'" >> /tmp/global.env

# WebDav
export WEBDAV_URL="http://${WEBDAV_HOST:-$AMQP_BUS_HOST}:8080"
export SEAHUB_DOMAIN=`echo $EYEOS_CARD | json domain`
export SEAHUB_USERNAME=`echo $EYEOS_USER`"@$SEAHUB_DOMAIN"

WRITABLE_HOME="/home/$SPICE_USER"
ENVARS="XDG_CONFIG_HOME=$WRITABLE_HOME/.config"
ENVARS="$ENVARS XDG_CACHE_HOME=$WRITABLE_HOME/.cache"
ENVARS="$ENVARS XDG_DATA_HOME=$WRITABLE_HOME/.local/share"
ENVARS="$ENVARS KDEHOME=$WRITABLE_HOME/.kde"

if [ "${USE_BIND_MOUNT_FOR_LIBRARIES}" ]
then
	WEBDAV_MOUNT_POINT="/mnt/seafdav"
	WORKING_DIRECTORY="/home/$EYEOS_USER"
	ENVARS="$ENVARS HOME=$WORKING_DIRECTORY"
	ENVARS="$ENVARS KDE_HOME_READONLY=true"
else
	WEBDAV_MOUNT_POINT="/home/$SPICE_USER/files"
	WORKING_DIRECTORY="$WEBDAV_MOUNT_POINT"
	ENVARS="$ENVARS HOME=$WEBDAV_MOUNT_POINT"
fi

export WEBDAV_MOUNT_POINT

if [ ! -d "$WEBDAV_MOUNT_POINT" ]; then
	mkdir "$WEBDAV_MOUNT_POINT"
fi

if [ ! -d "$WORKING_DIRECTORY" ]; then
	mkdir -p "$WORKING_DIRECTORY"
fi

JSON_PASSWORD="{\"c\":$EYEOS_MINI_CARD,\"s\":\"$EYEOS_MINI_SIGNATURE\"}"
WEBDAV_PASSWORD=`echo "$JSON_PASSWORD" | sed 's/"/#/g'`

echo "$WEBDAV_URL $SEAHUB_USERNAME \"$WEBDAV_PASSWORD\"" >> /etc/davfs2/secrets
mount -t davfs -o "noexec,nosuid,uid=$SPICE_USER" "$WEBDAV_URL" "$WEBDAV_MOUNT_POINT"

if [ "$USE_BIND_MOUNT_FOR_LIBRARIES" ]
then
	# making all libraries available from the webdav mountpoint in the user home
	# and removing write privilege to the user's home so it cannot save documents
	# there, which are not going to be synchronized with seafile
	chmod a-w "/home/$SPICE_USER" "/home/$SPICE_USER/files" || true
	/root/bind-mount-libraries --no-polling "$WEBDAV_MOUNT_POINT" "$WORKING_DIRECTORY"
	/root/bind-mount-libraries "$WEBDAV_MOUNT_POINT" "$WORKING_DIRECTORY" &
fi

xsetroot -solid rgb:F5/F6/F9 -cursor_name left_ptr

# Kontact takes forever to initialize the first time. We cannot launch the services
# before it is ready as that results in a black screen
# So we have a special case for mail, where the mail executable launches the open365-services
if [ "$1" != 'mail' ]; then
	su $SPICE_USER -c "open365-services.js &"
fi

su $SPICE_USER -c "DISPLAY=:2 /code/open365-services/src/clipboardData.js $1 &"
su $SPICE_USER -c "DISPLAY=:2 ratpoison &"
su $SPICE_USER -c "DISPLAY=:2 setxkbmap -model pc105 -layout es || true"

# Before launching libreoffice we need to remove the recent file list
sed -i.bck '/PickList/d' /home/user/.config/libreoffice/4/user/registrymodifications.xcu

# Remove the Libreoffice config once
# We reverted from LO 5.1 to 5.0, and certain config values break LO
# For now lets just remove everyone LO config :(
if [ ! -f /home/user/.config/open365_LO_deleted_1_Jun_2016 ]; then
    touch /home/user/.config/open365_LO_deleted_1_Jun_2016
    rm -rf  /home/user/.config/libreoffice
fi

export $ENVARS

# Run migrations if exists
if [ -x /usr/bin/open365-migrations ]; then
    /usr/bin/open365-migrations
fi

cd "$WORKING_DIRECTORY" && sudo -E -u "$SPICE_USER" DISPLAY=:2 "$@"
