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
# Function: delOldFile
#   Remove passed filename (all files matching passed pattern) if it exists
#   AND it is OLDER than $COMPFILE (also can recursively remove a directory)
#
#   Parameter 1: item pattern (for directory removal, have last character a "/")
#
#       NOTE: wrap passed filename in double quotes so that wildcards NOT expanded
#       or else every filename match will be a different parameter: we want file
#       pattern to be just one parameter passed to delOldFile function
#
#   Parameter 2: Comparison File (use touch -d "YYYY-MM-DD" to set the
#       modified date of this comparison file before passing to delOldFile.) 
#
#   Parameter 3: IGNORE Symlink OPTIONAL: if "YES", then will NOT delete
#       old file/folder IF it is a symlink
# ------------------------------------------------------------------------------
delOldFile () {
    # If last character is a "/", we are dealing with a diretory, and need to
    #   do "ls -d" instead of normal ls to list.
    LAST_CHAR=$(echo -n "$1" | tail -c1)
    # IFS command: Need to change delimiter in list to 'newline' instead of space.
    #   this way, for loop won't split apart if filename has a space
    #   warning, if use just sh instead of bash, need to have a literal newline
    OLDIFS=$IFS
    IFS=$'\n'
    # not sure why, but any spaces in $1 not a problem here ("Make PDF Booklet")
    #   If attempt to do "$1" (with quotes) then wildcard not expanded so don't
    #   want that.  So, keeping as is even though seems odd not needed.
    if [ "$LAST_CHAR" == "/" ];
    then
        #Directory pattern
        DEL_LIST=$(ls -d $1 2>/dev/null || true;)
    else
        #File pattern
        DEL_LIST=$(ls $1 2>/dev/null || true;)
    fi
    # if $DEL_LIST is empty (from above command), won't process
    if [ -n "$DEL_LIST" ];
    then
        # System Install Date taken from modified date of installer/version file
        INSTALL_DATE=$(date +%Y-%m-%d --reference=/var/log/installer/version)
        
        for DEL_FILE in $DEL_LIST; do
            
            DEL_FILE_DATE=$(date +%Y-%m-%d --reference="$DEL_FILE")
            
            if [ $3 == "YES" ] && [ -h "$DEL_FILE" ];
            then
                # don't process on this file - is a symlink
                echo
                echo "*** NOT Removing symlink: " $DEL_FILE
                echo
            else
                # Delete IF DEL_FILE older than Passed reference date OR
                #   if the date of DEL_FILE is the same as the system install date
                if [ "$DEL_FILE" -ot $2 ] || [ $DEL_FILE_DATE = $INSTALL_DATE ];
                then
                    echo
                    echo "*** Removing OLD item: " $DEL_FILE
                    echo
                    rm -r "$DEL_FILE"
                else
                    echo
                    echo "*** NOT Removing item (newer than legacy date): " $DEL_FILE
                    echo
                fi
            fi
        done
    fi

    # Return IFS to prior setting
    IFS=$OLDIFS
}


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
# Add LibreOffice 5.0 PPA
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

if ! [ -e $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list ];
then
    echo
    echo "*** Adding LibreOffice 5.0 $REPO_SERIES PPA"
    echo
    echo "deb http://ppa.launchpad.net/libreoffice/libreoffice-5-0/ubuntu $REPO_SERIES main" | \
        tee $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
    echo "# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-0/ubuntu $REPO_SERIES main" | \
        tee -a $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
else
    # found, but ensure Wasta-Linux PPA ACTIVE (user could have accidentally disabled)
    echo
    echo "*** LibreOffice 5.0 $REPO_SERIES PPA already exists, ensuring active"
    echo
    sed -i -e '$a deb http://ppa.launchpad.net/libreoffice/libreoffice-5-0/ubuntu '$REPO_SERIES' main' \
        -i -e '\@deb http://ppa.launchpad.net/libreoffice/libreoffice-5-0/ubuntu '$REPO_SERIES' main@d' \
        $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-0-$REPO_SERIES.list
fi

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

# For ALL users, delete LO config folder if older than specified date
#   (this will ensure that ODF file extensions used by system extension above)
#   since will be re-created when LO launched.  Effectively we are resetting
#   LO preferences.

# Create file with modified date of desired comparison time
#   so that don't remove a user's updated files if they have made a
#   custom update to them.

# 2017-02-09 rik: is this needed?  I thought the shared extensions would be added without resetting prefs???
COMPFILE=$(mktemp)
touch $COMPFILE -d '2015-01-26'

delOldFile "/home/*/.config/libreoffice/" $COMPFILE "YES"

# remove comparison time file
rm $COMPFILE

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
