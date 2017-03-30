#!/bin/bash

# ==============================================================================
# wasta-custom-ssg-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom-ssg.  It can be manually re-run, but is
#       only intended to be run at package installation.  
#
#   2013-12-03 rik: initial script
#   2014-01-20 rik: removed libreoffice logic to separate scripts
#   2014-02-20 rik: removed libreoffice prior logic, now install LO extension
#       to handle SSG default settings (this is persistent over LO upgrades).
#   2014-05-30 rik: a4 paper size setting.
#   2015-01-26 rik: fixing LO extension install so won't have user settings
#       owned by root (will make LO not be able to open) if user hasn't
#       opened LO before the extension is installed.
#       - removing ssg "non ODF" extension if installed
#   2015-02-09 rik: disable Graphite in LO desktop launchers.  With Graphite
#       enabled, spacing of SIL fonts for bold / normal not behaving correctly.
#       First used instance of font (even from different open document) will
#       define if bold or normal spacing used, regardless of whether actual
#       bold or normal characters are entered.  Disabling Graphite corrects
#       this problem.
#   2017-02-09 rik: adding LO 5.0 PPA
#       - adding 'disable VBA refactoring' LO extension for all users
#   2017-03-25 rik: XENIAL BUILD ONLY adding 5.2 PPA, removing 5.0,5.1,4.4 ppas
#       - removing delete of LO settings (was done if settings were old but
#       this shouldn't be needed by using extensions?
#   2017-03-30 rik: add wasta-custom-ssg/resources/goldendict to goldendict
#       dictionary paths (for all users)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
	echo
	echo "You must run this script with sudo." >&2
	echo "Exiting...."
	sleep 5s
	exit 1
fi

# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

echo
echo "*** Beginning wasta-custom-ssg-postinst.sh"
echo

# setup directory for reference later
DIR=/usr/share/wasta-custom-ssg/resources

# ------------------------------------------------------------------------------
# Symlinking scripts to /usr/bin so can run without path from terminal
# ------------------------------------------------------------------------------
echo
echo "*** Adding ssg-kmfl-setup.sh symlink to /usr/bin"
echo
ln -sf $DIR/ssg-kmfl-setup.sh /usr/bin/ssg-kmfl-setup

# ------------------------------------------------------------------------------
# Add LibreOffice 5.2 PPA
# ------------------------------------------------------------------------------

# get series, load them up.
SERIES=$(lsb_release -sc)
case "$SERIES" in

  precise|maya)
    #LTS 12.04-based Mint 13.x
    REPO_SERIES="precise"
  ;;

  trusty|qiana|rebecca|rafaela|rosa)
    #LTS 14.04-based Mint 17.x
    REPO_SERIES="trusty"
  ;;

  xenial|sarah)
    #LTS 16.04-based Mint 18.x
    REPO_SERIES="xenial"
  ;;

  *)
    # Don't know the series, just go with what is reported
    REPO_SERIES=$SERIES
  ;;
esac

APT_SOURCES=/etc/apt/sources.list

if ! [ -e $APT_SOURCES.wasta ];
then
    APT_SOURCES_D=/etc/apt/sources.list.d
else
    # wasta-offline active: adjust apt file locations
    echo
    echo "*** wasta-offline active, applying repository adjustments to /etc/apt/sources.list.wasta"
    echo
    APT_SOURCES=/etc/apt/sources.list.wasta
    if [ "$(ls -A /etc/apt/sources.list.d)" ];
    then
        echo
        echo "*** wasta-offline 'offline and internet' mode detected"
        echo
        # files inside /etc/apt/sources.list.d so it is active
        # wasta-offline "offline and internet mode": no change to sources.list.d
        APT_SOURCES_D=/etc/apt/sources.list.d
    else
        echo
        echo "*** wasta-offline 'offline only' mode detected"
        echo
        # no files inside /etc/apt/sources.list.d
        # wasta-offline "offline only mode": change to sources.list.d.wasta
        APT_SOURCES_D=/etc/apt/sources.list.d.wasta
    fi
fi

# first backup $APT_SOURCES in case something goes wrong
# delete $APT_SOURCES.save if older than 30 days
find /etc/apt  -maxdepth 1 -mtime +30 -iwholename $APT_SOURCES.save -exec rm {} \;

if ! [ -e $APT_SOURCES.save ];
then
    cp $APT_SOURCES $APT_SOURCES.save
fi

if ! [ -e $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2-$REPO_SERIES.list ];
then
    echo
    echo "*** Adding LibreOffice 5.2 $REPO_SERIES PPA"
    echo
    echo "deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu $REPO_SERIES main" | \
        tee $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
    echo "# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu $REPO_SERIES main" | \
        tee -a $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
else
    # found, but ensure LO 5.2 PPA ACTIVE (user could have accidentally disabled)
    echo
    echo "*** LibreOffice 5.2 $REPO_SERIES PPA already exists, ensuring active"
    echo
    sed -i -e '$a deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu '$REPO_SERIES' main' \
        -i -e '\@deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu '$REPO_SERIES' main@d' \
        $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
fi

# remove 5.0, 4.4 PPAs if exist
rm -f $APT_SOURCES_D/libreoffice-libreoffice-5-0*
rm -f $APT_SOURCES_D/libreoffice-libreoffice-5-1*
rm -f $APT_SOURCES_D/libreoffice-libreoffice-4-4* # could be leftover from precise settings run on xenial

# ------------------------------------------------------------------------------
# LibreOffice Preferences Extension install (for all users)
# ------------------------------------------------------------------------------

# REMOVE "Disable VBA Refactoring" extension: only way to update is
#   remove then reinstall
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/disable-vba-refactoring* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared disable-vba-refactoring.oxt
fi

# Install disable-vba-refactoring.oxt
echo
echo "*** Installing/Upating Disable VBA Refactoring LO Extension"
echo
unopkg add --shared $DIR/disable-vba-refactoring.oxt

# REMOVE "Disable VBA Refactoring" extension: only way to update is
#   remove then reinstall
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/wasta-ssg-odf-defaults* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared wasta-ssg-odf-defaults.oxt
fi

# Install wasta-ssg-defaults.oxt (Default LibreOffice Preferences)
echo
echo "*** Installing SSG LO ODF Default Settings Extension (for all users)"
echo
unopkg add --shared $DIR/wasta-ssg-odf-defaults.oxt

# REMOVE "Non-ODF" extension: default for SSG is now ODF
# Send error to null so won't display
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/wasta-ssg-defaults* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared wasta-ssg-defaults.oxt
fi

# IF user has not initialized LibreOffice, then when adding the above shared
#   extension, the user's LO settings are created, but owned by root so
#   they can't change them: solution is to just remove them (will get recreated
#   when user starts LO the first time).

for LO_FOLDER in /home/*/.config/libreoffice;
do
    LO_OWNER=$(stat -c '%U' $LO_FOLDER)

    if [ "$LO_OWNER" == "root" ];
    then
        echo
        echo "*** LibreOffice settings owned by root: resetting"
        echo "*** Folder: $LO_FOLDER"
        echo
    
        rm -rf $LO_FOLDER
    fi
done

# ------------------------------------------------------------------------------
# ibus: load up "standard" keyboards for users
# This assumes ibus 1.5+ (so doesn't work for precise)
# ------------------------------------------------------------------------------
LOCAL_USERS=""
for USER_FOLDER in $(ls -1 home)
do
    # if user is in /etc/passwd then it is a 'real user' as opposed to
    # something like wasta-remastersys
    if [ "$(grep $USER_FOLDER /etc/passwd)" ];
    then
        LOCAL_USERS+="$USER_FOLDER "
    fi
done

for CURRENT_USER in $LOCAL_USERS;
do
    # not sure why these are owned by root sometimes but shouldn't be
    chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/ibus
    chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.cache/dconf

    # need to know if need to start dbus for user
    # don't use dbus-run-session for logged in user or it doesn't work
    LOGGED_IN_USER="${SUDO_USER:-$USER}"
    if [[ "$LOGGED_IN_USER" == "$CURRENT_USER" ]];
    then
        #echo "login is same as current: $CURRENT_USER"
        DBUS_SESSION=""
    else
        #echo "user not logged in, running update with dbus: $CURRENT_USER"
        DBUS_SESSION="dbus-run-session --"
    fi

    IBUS_ENGINES=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general preload-engines")
    ENGINES_ORDER=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general engines-order")

    # remove legacy engine names
    # (, \)\{0,1\} removes any OPTIONAL ", " preceding the kmfl keyboard name
    #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/SILEthiopic-1.3.kmn'@@" <<<"$IBUS_ENGINES")
    #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-el-ethiopian-latin.kmn'@@" <<<"$IBUS_ENGINES")
    #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/EL.kmn'@@" <<<"$IBUS_ENGINES")
    #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-pwrgeez.kmn'@@" <<<"$IBUS_ENGINES")

    if [[ "$IBUS_ENGINES" == *"[]"* ]];
    then
        echo
        echo "!!!NO ibus preload-engines found for user: $CURRENT_USER"
        echo
        # no engines currently: shouldn't normally happen so add en US as a fallback base
        IBUS_ENGINES="['xkb:us::eng']"
    fi

    AR_INSTALLED=$(grep "xkb:ara::ara" <<<"$IBUS_ENGINES")
    if [[ -z "$AR_INSTALLED" ]];
    then
        echo
        echo "Installing Arabic keyboard for user: $CURRENT_USER"
        echo
        # append engine to list
        IBUS_ENGINES=$(sed -e "s@']@', 'xkb:ara::ara']@" <<<"$IBUS_ENGINES")
    fi

    GE_INSTALLED=$(grep GE.kmn <<<"$IBUS_ENGINES")
    if [[ -z "$GE_INSTALLED" ]];
    then
        echo
        echo "Installing GE keyboard for user: $CURRENT_USER"
        echo
        # append engine to list
        IBUS_ENGINES=$(sed -e "s@']@', '/usr/share/kmfl/GE.kmn']@" <<<"$IBUS_ENGINES")
    fi

    # set engines
    su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings set org.freedesktop.ibus.general preload-engines \"$IBUS_ENGINES\"" >/dev/null 2>&1

    # restart ibus
    su -l "$CURRENT_USER" -c "$DBUS_SESSION ibus restart" >/dev/null 2>&1
done 

# ------------------------------------------------------------------------------
# goldendict add wasta-custom-ssg path for dictionaries (all users)
# ------------------------------------------------------------------------------
echo
echo "*** Ensuring Arabic <==> English GoldenDict Dictionaries Installed (for all users)"
echo
# touch files first to make sure exist
touch /home/*/.goldendict/config
touch /etc/skel/.goldendict/config

# FIRST delete existing element
# rik: can't get hte xmlstarlet to delete only the right path, so just using sed
#xmlstarlet ed --inplace --delete 'config/paths/path[path="/usr/share/wasta-custom-ssg/resources/goldendict"]'     /home/*/.goldendict/config
sed -i -e '\@usr/share/wasta-custom-ssg/resources/goldendict@d' \
    /home/*/.goldendict/config /etc/skel/.goldendict/config

# create it with element name pathTMP, then can apply attr and then rename to path
xmlstarlet ed --inplace -s 'config/paths' -t elem -n 'pathTMP' \
        -v '/usr/share/wasta-custom-ssg/resources/goldendict' \
    -s 'config/paths/pathTMP' -t attr -n 'recursive' -v '0' \
    -r 'config/paths/pathTMP' -v path \
    /home/*/.goldendict/config /etc/skel/.goldendict/config

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-ssg-postinst.sh"
echo

exit 0
