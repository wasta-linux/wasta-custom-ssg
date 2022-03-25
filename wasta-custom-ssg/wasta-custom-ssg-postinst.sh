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
#   2018-03-20 rik: adjusting goldendict updates to be run for each user.
#       - Correcting LO extension installs.
#       - adding LO 5.4 PPA for xenial
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

# get series (no longer compatible with Linux Mint)
SERIES=$(lsb_release -sc)

# ------------------------------------------------------------------------------
# Adjust Software Sources
# ------------------------------------------------------------------------------

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

# manually add Skype and LO repo keys (since wasta-offline could be active)
# apt-key add $DIR/keys/libreoffice-ppa.gpg >/dev/null 2>&1;
# apt-key add $DIR/keys/skype.gpg >/dev/null 2>&1;

if [ "$SERIES" == "bionic" ] || [ "$SERIES" == "focal" ];
then
    if ! [ -e $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-2-$SERIES.list ];
    then
        echo
        echo "*** Adding Wasta-Linux LibreOffice 7.2 $SERIES PPA"
        echo
        echo "deb http://ppa.launchpad.net/wasta-linux/libreoffice-7-2/ubuntu $SERIES main" | \
            tee $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-2-$SERIES.list
        echo "# deb-src http://ppa.launchpad.net/wasta-linux/libreoffice-7-2/ubuntu $SERIES main" | \
            tee -a $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-2-$SERIES.list
    else
        # found, but ensure LO 7.2 PPA ACTIVE (user could have accidentally disabled)
        echo
        echo "*** Wasta-Linux LibreOffice 7.2 $SERIES PPA already exists, ensuring active"
        echo
        # DO NOT match any lines ending in #wasta
        sed -i -e '/#wasta$/! s@.*\(deb http://ppa.launchpad.net\)@\1@' \
            $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-2-$SERIES.list
    fi
fi

# Remove older LO PPAs
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-1*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-3*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-4*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-0*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-1*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-2*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-3*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-4*
rm -rf $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-1*

# Add Skype Repository
#if ! [ -e $APT_SOURCES_D/skype-stable.list ];
#then
#    echo
#    echo "*** Adding Skype Repository"
#    echo

#    echo "deb https://repo.skype.com/deb stable main" | \
#        tee $APT_SOURCES_D/skype-stable.list
#fi

# ------------------------------------------------------------------------------
# Set Wasta-Layout default
# ------------------------------------------------------------------------------
# TODO: need to NOT run if the default has already been overridden

#if [ -e "/usr/bin/wasta-layout" ];
#then
#    if [ $(find /usr/share/glib-2.0/schemas/*wasta-layout* -maxdepth 1 -type l 2>/dev/null) ];
#    then
#        echo
#        echo "*** Wasta-Layout already set: not updating"
#        echo
#    else
#        echo
#        echo "*** Setting Wasta-Layout default to redmond7"
#        echo
#        wasta-layout-system redmond7
#    fi
#fi

# ------------------------------------------------------------------------------
# Dconf / Gsettings default value adjustments
# ------------------------------------------------------------------------------
# Override files in /usr/share/glib-2.0/schemas/ folder.
#   Values in z_20_wasta-custom-eth.gschema.override will override values
#   in z_10_wasta-core.gschema.override which will override Ubuntu defaults.
echo
echo "*** Updating dconf / gsettings default values"
echo
# Sending any "error" to null (if a key isn't found it will return an error,
#   but for different version of Cinnamon, etc., some keys may not exist but we
#   don't want to error in this case: suppressing errors to not worry user.
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true;

# ------------------------------------------------------------------------------
# LibreOffice Fixes
# ------------------------------------------------------------------------------
for LO_FOLDER in /home/*/.config/libreoffice;
do
    LO_OWNER=""
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
# Disable "whoopsie" if found: daisy.ubuntu.com blocked by EthioTelecom
#   so hangs shutdown
# ------------------------------------------------------------------------------
if [ -x "/usr/bin/whoopsie" ];
then
    echo
    echo "*** Disabling 'whoopsie' error reporting"
    echo
    systemctl disable whoopsie.service >/dev/null 2>&1
fi

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Install hp-plugin (non-interactive)
# ------------------------------------------------------------------------------
# Install hp-plugin automatically: needed by some HP printers such as black
#   HP m127 used by SIL Ethiopia. Don't display output to confuse user.

case "$SERIES" in
  bionic)
    echo
    echo "*** bionic: installing hp-plugin"
    yes | hp-plugin -p $DIR/hp-plugin-bionic/ >/dev/null 2>&1
    echo "*** bionic: hp-plugin install complete"
  ;;
  focal)
    echo
    echo "*** focal: installing hp-plugin"
    yes | hp-plugin -p $DIR/hp-plugin-focal/ >/dev/null 2>&1
    echo "*** focal: hp-plugin install complete"
  ;;
esac

echo

# ------------------------------------------------------------------------------
# Disable any apt.conf.d "nocache" file (from wasta-core)
# ------------------------------------------------------------------------------
# The nocache option for apt prevents local cache from squid (used by pfsense
# at main Addis office) from being used.  Need to disable.

if [ -e /etc/apt/apt.conf.d/99nocache ];
then
    sed -i -e 's@^Acquire@#Acquire@' /etc/apt/apt.conf.d/99nocache
fi

# ------------------------------------------------------------------------------
# enable zswap (from wasta-core if found)
# ------------------------------------------------------------------------------
# Ubuntu / Wasta-Linux 20.04 swaps really easily, which kills performance.
# zswap uses *COMPRESSED* RAM to buffer swap before writing to disk.
# This is good for SSDs (less writing), and good for HDDs (no stalling).
# zswap should NOT be used with zram (uncompress/recompress shuffling).

if [ -e "/usr/bin/wasta-enable-zswap" ];
then
    wasta-enable-zswap auto
fi

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-ssg-postinst.sh"
echo

exit 0

# ------------------------------------------------------------------------------
# Legacy stuff below..........
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ibus: load up "standard" keyboards for users
# This assumes ibus 1.5+ (so doesn't work for precise)
# ------------------------------------------------------------------------------
#
# 2018-09-19: commenting out as we rely on the gschema.override to set default
#   keyboards for new users
#
#LOCAL_USERS=""
#for USER_FOLDER in $(ls -1 /home)
#do
#    # if user is in /etc/passwd then it is a 'real user' as opposed to
#    # something like wasta-remastersys
#    if [ "$(grep $USER_FOLDER /etc/passwd)" ];
#    then
#        LOCAL_USERS+="$USER_FOLDER "
#    fi
#done
#
#for CURRENT_USER in $LOCAL_USERS;
#do
#    # --------------------------------------------------------------------------
#    # ibus: load up "standard" keyboards for users
#    # This assumes ibus 1.5+ (so doesn't work for precise)
#    # --------------------------------------------------------------------------
#    if [ "$REPO_SERIES" != "precise" ];
#    then
#        # not sure why these are owned by root sometimes but shouldn't be
#        chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/ibus
#        chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.cache/dconf

#        # need to know if need to start dbus for user
#        # don't use dbus-run-session for logged in user or it doesn't work
#        LOGGED_IN_USER="${SUDO_USER:-$USER}"
#        if [[ "$LOGGED_IN_USER" == "$CURRENT_USER" ]];
#        then
#            #echo "login is same as current: $CURRENT_USER"
#            DBUS_SESSION=""
#        else
#            #echo "user not logged in, running update with dbus: $CURRENT_USER"
#            DBUS_SESSION="dbus-run-session --"
#        fi

#        IBUS_ENGINES=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general preload-engines")
#        ENGINES_ORDER=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general engines-order")

#        # remove legacy engine names
#        # (, \)\{0,1\} removes any OPTIONAL ", " preceding the kmfl keyboard name
#        #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/SILEthiopic-1.3.kmn'@@" <<<"$IBUS_ENGINES")
#        #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-el-ethiopian-latin.kmn'@@" <<<"$IBUS_ENGINES")
#        #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/EL.kmn'@@" <<<"$IBUS_ENGINES")
#        #IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-pwrgeez.kmn'@@" <<<"$IBUS_ENGINES")

#        if [[ "$IBUS_ENGINES" == *"[]"* ]];
#        then
#            echo
#            echo "!!!NO ibus preload-engines found for user: $CURRENT_USER"
#            echo
#            # no engines currently: shouldn't normally happen so add en US as a fallback base
#            IBUS_ENGINES="['xkb:us::eng']"
#        fi

#        AR_INSTALLED=$(grep "xkb:ara::ara" <<<"$IBUS_ENGINES")
#        if [[ -z "$AR_INSTALLED" ]];
#        then
#            echo
#            echo "Installing Arabic keyboard for user: $CURRENT_USER"
#            echo
#            # append engine to list
#            IBUS_ENGINES=$(sed -e "s@']@', 'xkb:ara::ara']@" <<<"$IBUS_ENGINES")
#        fi

#        GE_INSTALLED=$(grep GE.kmn <<<"$IBUS_ENGINES")
#        if [[ -z "$GE_INSTALLED" ]];
#        then
#            echo
#            echo "Installing GE keyboard for user: $CURRENT_USER"
#            echo
#            # append engine to list
#            IBUS_ENGINES=$(sed -e "s@']@', '/usr/share/kmfl/GE.kmn']@" <<<"$IBUS_ENGINES")
#        fi

#        # set engines
#        su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings set org.freedesktop.ibus.general preload-engines \"$IBUS_ENGINES\"" >/dev/null 2>&1

#        # restart ibus
#        su -l "$CURRENT_USER" -c "$DBUS_SESSION ibus restart" >/dev/null 2>&1
#    fi

#    # --------------------------------------------------------------------------
#    # goldendict add wasta-custom-ssg path for dictionaries (all users)
#    # --------------------------------------------------------------------------
#    echo
#    echo "*** Ensuring Arabic <==> English GoldenDict Dictionaries Installed (for all users)"
#    echo
#    # touch files first to make sure exist
#    touch /home/$CURRENT_USER/.goldendict/config
#    touch /etc/skel/.goldendict/config

#    # ensure user file owned by user
#    chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.goldendict/config

#    # FIRST delete existing element
#    # rik: can't get xmlstarlet to delete only the right path, so just using sed
#    #xmlstarlet ed --inplace --delete 'config/paths/path[path="/usr/share/wasta-custom-ssg/resources/   goldendict"]'     /home/*/.goldendict/config
#    su -l "$CURRENT_USER" -c "sed -i -e '\@usr/share/wasta-custom-ssg/resources/goldendict@d' /home/$CURRENT_USER/.goldendict/config /etc/skel/.goldendict/config"

#    # create it with element name pathTMP, then can apply attr and then rename to path
#    su -l "$CURRENT_USER" -c "xmlstarlet ed --inplace -s 'config/paths' -t elem -n 'pathTMP' \
#        -v '/usr/share/wasta-custom-ssg/resources/goldendict' \
#        -s 'config/paths/pathTMP' -t attr -n 'recursive' -v '0' \
#        -r 'config/paths/pathTMP' -v path \
#        /home/$CURRENT_USER/.goldendict/config /etc/skel/.goldendict/config"

#done

