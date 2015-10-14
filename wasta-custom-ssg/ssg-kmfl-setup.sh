#!/bin/bash

# ==============================================================================
# SSG iBus Keyboard installation and setup (for KMFL and m17n keyboards)
#
#  The GUI way to do this is to copy the .kmn files to /usr/share/kmfl
#        then run Keyboard Input Methods (Ubuntu) / iBus Preferences (Mint)
#        and go to the Input Methods tab, Select an input method | Other |
#        <kmfl keyboard>, and press ADD
#
#   2012-12-16: Initial script (split from 1-ibus-kmfl-install.sh script)
#   2013-01-01: Merged back to single script, added superuser block.
#   2013-03-22: Updated to handle any type of file for icon (instead of just
#       .bmp files.  TODO: make case-insensitive for file names.
#   2013-03-22: Reworked for distribution with wasta-custom-ssg package
#       TODO: look into possibly using zeinity for user interaction??
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Setup script to run with superuser permissions
# ------------------------------------------------------------------------------
if [ "$(whoami)" != "root" ]; then
    echo
    echo "This script needs to run with superuser permissions."
    echo "----------------------------------------------------"
    # below will return <blank> if user not in sudo group
    OUT=$(groups $(whoami) | grep "sudo")

    if [ "$OUT" ]; then
        # user has sudo permissions: use them to re-run the script
        echo
        echo "If prompted, enter the sudo password."
        #re-run script with sudo
        sudo bash $0
        LASTERRORLEVEL=$?
    else
        #user doesn't have sudo: limited user, so prompt for sudo user
        until [ "$OUT" ]; do
            echo
            echo "Current user doesn't have sudo permissions."
            echo
            read -p "Enter admin id (blank for root) to run this script:  " SUDO_ID

            # set SUDO_ID to root if not entered
            if [ "$SUDO_ID" ]; then
                OUT=$(groups ${SUDO_ID} | grep "sudo")
            else
                SUDO_ID="root"
                # manually assign $OUT to anything because we will use root!
                OUT="root"
            fi
        done

        # re-run script with $SUDO_ID 
        echo
        echo "Enter password for $SUDO_ID (need to enter twice)."
        su -l $SUDO_ID -c "sudo bash $0"
        LASTERRORLEVEL=$?

        # give 2nd chance if entered pwd wrong (su doesn't give 2nd chance)
        if [ $LASTERRORLEVEL == 1 ]; then
            su -l $SUDO_ID -c "sudo bash $0"
            LASTERRORLEVEL=$?
        fi
    fi

    echo
    read -p "FINISHED:  Press <ENTER> to exit..."
    exit $LASTERRORLEVEL
fi

# ------------------------------------------------------------------------------
# Initial prompt
# ------------------------------------------------------------------------------
echo
echo "========================================================================="
echo "=== SSG kmfl (Keyman) Keyboard installation and setup ==================="
echo "========================================================================="
echo
echo "This script will install and set up kmfl (Keyman) and m17n (standard"
echo "  language such as Arabic) keyboards for use with iBus."
echo
echo "This scipt will also install ibus-kmfl and SIL fonts."
echo
echo "NOTE: If ONLY Arabic is wanted (no Keyman keyboards are wanted), then"
echo "      don't use this script to set up ibus-kmfl but instead add Arabic"
echo "      through 'Keyboard Layout' preference panel in 'System Settings'."
echo
echo "Close this window if you do not want to run this script."
echo
read -p "Press <Enter> to continue..."

set -e

# ------------------------------------------------------------------------------
# Install SIL Fonts
# ------------------------------------------------------------------------------
echo
echo "*** Ensuring kmfl and SIL fonts installed"
echo

until [ -x /usr/lib/ibus-kmfl/ibus-engine-kmfl ]; do
    echo
    echo "*** Updating system and installing ibus-kmfl and SIL fonts"
    sleep 3s
    echo

    apt-get update

    apt-get --yes install \
        ibus-kmfl \
        fonts-sil-andika \
        fonts-sil-andika-compact \
        fonts-sil-charissil \
        fonts-sil-doulossil \
        fonts-sil-gentiumplus \
        fonts-sil-gentiumpluscompact
done

# 2013-10-21: NOTE: all SSG keyboards and icons installed by the package
#   This script will just set which will appear in the taskbar icon.

# ------------------------------------------------------------------------------
# Set up desired keyman keyboards
# ------------------------------------------------------------------------------

IBUS_KMN='start'
MORE_KMN='Y'
ADD_KMN=''
while [ "[${MORE_KMN^^}]" = "[Y]" ]; do
    clear
    echo 'Enter code for Keyman Table you want to add to system.'
    echo '    For example, enter "GE" (no quotes) to add GE.kmn to system.'
    echo
    echo '    Keyman Table Choices:'
    echo
    echo '        GE        BDH       BVI'
    echo
    echo '        DID       DIN       KRS'
    echo
    echo '        MIT       MM        MV'
    echo
    echo '                  TEX         '
    echo
    read -p 'Enter your table choice here:  ' ADD_KMN

    # Keyman files are UPPER.kmn, so ensure upper case
    # TODO aji 2013-03-22: try to fix so can have mixed case files but still case insensitive
    UPPER_ADD_KMN=${ADD_KMN^^}
    if [ $IBUS_KMN == 'start' ]; then
        IBUS_KMN="/usr/share/kmfl/"$UPPER_ADD_KMN".kmn"
    else
        IBUS_KMN=$IBUS_KMN',/usr/share/kmfl/'$UPPER_ADD_KMN'.kmn'
    fi

    echo
    echo "=== MORE KEYMAN TABLES? ==="
    echo
    read -p 'Do you have more Keyman Tables to add (y/n*)?  ' MORE_KMN
done

echo
echo "========================================================================="
echo "=== SETUP FOR ARABIC? ==================================================="
echo "========================================================================="
echo
read -p "Should we install Arabic in ibus (y/n*)?  " IBUS_ARABIC
echo

if [ "[${IBUS_ARABIC^^}]" = "[Y]" ];
then
    until [ -e //usr/lib/ibus-m17n/ibus-engine-m17n ]; do
        echo
        echo "*** Updating system and installing m17n for Arabic keyboard"
        sleep 3s
        echo

        apt-get update

        # ibus-m17n: needed for language options in ibus if use kmfl (Arabic)
        # hunspell-ar: needed for Arabic spelling check (Libre Office)
        apt-get --yes install ibus-m17n hunspell-ar
    done
    # set folder
    IBUS_ARABIC=',m17n:ar:kbd'
else
    IBUS_ARABIC=''
fi

# ------------------------------------------------------------------------------
# Load selected keyboards in ibus, and make ibus the language input method of choice
# ------------------------------------------------------------------------------
# Load selected keyboards in ibus
#    WARNING!!  You likely will not notice these gconftool-2 changing until you logout!!
#    pkill -HUP gconfd-2,ibus-gconf && ibus-daemon -xrd #should let you see the changes

echo
echo "*** Loading keyboards and setting up ibus as keyboard input method in"
echo "      Language Support (en_US and en_GB) for ALL users"
echo

# all current users:
# get user list lifted from here:
#   http://stackoverflow.com/questions/16633614/shell-script-to-get-list-of-defined-users-on-linux
USER_LIST=$(getent passwd | \
grep -vE '(nologin|false)$' | \
awk -F: -v min=`awk '/^UID_MIN/ {print $2}' /etc/login.defs` \
-v max=`awk '/^UID_MAX/ {print $2}' /etc/login.defs` \
'{if(($3 >= min)&&($3 <= max)) print $1}' | \
sort -u)

for USER in $USER_LIST; do
    echo
    echo "*** Loading selected keyboards in ibus for user: "$USER
    echo
    sudo -u $USER gconftool-2 --type=list --list-type=string -s \
        /desktop/ibus/general/preload_engines [$IBUS_KMN$IBUS_ARABIC]

    echo
    echo "*** Setting ibus as default input method for user: "$USER
    echo
    sudo -u $USER mkdir -p /home/$USER/.xinput.d
    sudo -u $USER ln -sf /etc/X11/xinit/xinput.d/ibus /home/$USER/.xinput.d/en_US
    sudo -u $USER ln -sf /etc/X11/xinit/xinput.d/ibus /home/$USER/.xinput.d/en_GB
    
    # In UNITY (if found), whitelist ALL in Unity so ibus icon will show up
    #UNITY_FOUND=$(sudo -u $USER gsettings list-recursively | \
    #    grep desktop.unity.panel || true;)
    UNITY_FOUND=$(sudo -u $USER dconf dump / | grep desktop/unity/panel || true;)
    if [ -n "$UNITY_FOUND" ];
    then
        echo
        echo "*** Unity: whitelisting ALL so ibus icon will show in panel"
        echo
        sudo -u $USER gsettings set desktop.unity.panel systray-whitelist "['all']"
    fi
done

# root
echo
echo "*** Loading selected keyboards in ibus for root"
echo
sudo -u root gconftool-2 --type=list --list-type=string -s \
    /desktop/ibus/general/preload_engines [$IBUS_KMN$IBUS_ARABIC]

echo
echo "*** Setting ibus as default input method for root"
echo
mkdir -p /root/.xinput.d
ln -sf /etc/X11/xinit/xinput.d/ibus /root/.xinput.d/en_US
ln -sf /etc/X11/xinit/xinput.d/ibus /root/.xinput.d/en_GB

# /etc/skel (template for new users: copy from root)
echo
echo "*** Loading selected keyboards in ibus for default user template"
echo
mkdir -p /etc/skel/.gconf/desktop
cp -rf /root/.gconf/desktop/ibus/ /etc/skel/.gconf/desktop/

echo
echo "*** Setting ibus as default input method for default user template"
echo
mkdir -p /etc/skel/.xinput.d
ln -sf /etc/X11/xinit/xinput.d/ibus /etc/skel/.xinput.d/en_US
ln -sf /etc/X11/xinit/xinput.d/ibus /etc/skel/.xinput.d/en_GB

# ------------------------------------------------------------------------------
# LEGACY WASTA CLEANUP (cleanup of prior tweaks now handled differently)
# ------------------------------------------------------------------------------

# removing LEGACY wasta hack for ibus manual auto-start
echo
echo "*** Removing LEGACY wasta ibus startup method"
echo

rm -f /etc/xdg/autostart/ibus-daemon.desktop

# ------------------------------------------------------------------------------
# reload ibus-daemon (if already running, if not, start it up!)
# ------------------------------------------------------------------------------
# do this from current logged on user, not from root (if used):
sudo -u $(logname) ibus-daemon -xrd

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
printf "\n\n\n\n\n\n"
echo "========================================================================="
echo "=== Script Finished ====================================================="
echo "========================================================================="
echo
echo "You may need to logout / login for correct keyboards to show"
echo "  under the ibus icon in system tray."

exit 0
