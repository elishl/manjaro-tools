#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# $1: chroot
configure_user(){
	# set up user and password
	local pass=$(gen_pw)
	msg2 "Creating user ${username} with password ${password} ..."
	chroot-run $1 useradd -m -g users -G ${addgroups} -p ${pass} ${username}
}

# $1: chroot
configure_hostname(){
	msg2 "Setting hostname ${hostname} ..."
	if [[ -f $1/usr/bin/openrc ]];then
	    local _hostname='hostname="'${hostname}'"'
	    sed -i -e "s|^.*hostname=.*|${_hostname}|" $1/etc/conf.d/hostname
	else
	    echo ${hostname} > $1/etc/hostname
	fi
}

configure_plymouth(){
    if [ -e $1/etc/plymouth/plymouthd.conf ] ; then
	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" $1/etc/plymouth/plymouthd.conf
    fi
}

configure_services(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${startservices_openrc[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	      ln -sf /etc/init.d/$svc $1/etc/runlevels/default/$svc
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${startservices_systemd[@]}; do
	      msg2 "Setting $svc ..."
	      if [[ -f $1/usr/lib/systemd/system/$svc ]];then
		  msg2 "Setting $svc ..."
		  chroot-run $1 systemctl enable $svc
	      fi
# 	      if [[ -f $1/etc/systemd/system/$svc ]];then
# 		  msg2 "Setting $svc ..."
# 		  chroot-run $1 systemctl enable $svc
# 	      fi
      done
   fi
}

# $1: chroot
configure_displaymanager(){
    _displaymanager=''
    msg2 "Configuring Displaymanager ..."
    # do_setuplightdm
    if [ -e "$1/usr/bin/lightdm" ] ; then
	#mkdir -p /run/lightdm > /dev/null

	if [ -e "$1/usr/bin/startxfce4" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=xfce/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=cinnamon/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=mate/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=enlightenment/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=openbox/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=LXDE/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=lxqt/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/pekwm" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=pekwm/' $1/etc/lightdm/lightdm.conf
	fi
	sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" $1/etc/lightdm/lightdm.conf
	sed -i -e 's/^.*autologin-user-timeout=.*/autologin-user-timeout=0/' $1/etc/lightdm/lightdm.conf
      #    sed -i -e 's/^.*autologin-in-background=.*/autologin-in-background=true/' /etc/lightdm/lightdm.conf
      
	chroot-run $1 groupadd autologin
	chroot-run $1 gpasswd -a ${username} autologin &> /dev/null
	chroot-run $1 chmod +r /etc/lightdm/lightdm.conf
	# livecd fix
	mkdir -p $1/var/lib/lightdm-data
	
	if [[ -e /run/systemd ]]; then
	    chroot-run $1 systemd-tmpfiles --create /usr/lib/tmpfiles.d/lightdm.conf
	    chroot-run $1 systemd-tmpfiles --create --remove
	fi
	_displaymanager='lightdm'
    fi

    # do_setupkdm
    if [ -e "$1/usr/share/config/kdm/kdmrc" ] ; then

	chroot-run $1 xdg-icon-resource forceupdate --theme hicolor &> /dev/null
	if [ -e "$1/usr/bin/update-desktop-database" ] ; then
	    chroot-run $1 update-desktop-database -q
	fi
	sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" $1/usr/share/config/kdm/kdmrc
	sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${username}/" $1/usr/share/config/kdm/kdmrc
	
	_displaymanager='kdm'
    fi

    # do_setupgdm
    if [ -e "$1/usr/bin/gdm" ] ; then

	if [ -d "$1/var/lib/AccountsService/users" ] ; then
	    echo "[User]" > $1/var/lib/AccountsService/users/gdm
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
		echo "XSession=xfce" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		echo "XSession=cinnamon" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		echo "XSession=mate" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		echo "XSession=enlightenment" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		echo "XSession=openbox" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/startlxde" ] ; then
		echo "XSession=LXDE" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		echo "XSession=LXQt" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    echo "Icon=" >> $1/var/lib/AccountsService/users/gdm
	fi
      _displaymanager='gdm'
    fi

    # do_setupmdm
    if [ -e "$1/usr/bin/mdm" ] ; then

	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i 's|default.desktop|xfce.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i 's|default.desktop|cinnamon.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i 's|default.desktop|openbox.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i 's|default.desktop|mate.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    sed -i 's|default.desktop|LXDE.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i 's|default.desktop|lxqt.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i 's|default.desktop|enlightenment.desktop|g' $1/etc/mdm/custom.conf
	fi
	_displaymanager='mdm'
    fi

    # do_setupsddm
    if [ -e "$1/usr/bin/sddm" ] ; then

	sed -i -e "s|^User=.*|User=${username}|" $1/etc/sddm.conf
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i -e 's|^Session=.*|Session=xfce.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=cinnamon.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=openbox.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=mate.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/lxsession" ] ; then
	    sed -i -e 's|^Session=.*|Session=LXDE.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=lxqt.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i -e 's|^Session=.*|Session=enlightenment.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/startkde" ] ; then
	    sed -i -e 's|^Session=.*|Session=plasma.desktop|' $1/etc/sddm.conf
	fi
	_displaymanager='sddm'
    fi

    # do_setuplxdm
    if [ -e "$1/usr/bin/lxdm" ] ; then

	sed -i -e "s/^.*autologin=.*/autologin=${username}/" $1/etc/lxdm/lxdm.conf
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/startxfce4|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/cinnamon-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/mate-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/enlightenment_start|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/openbox-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxsession|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxqt-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/pekwm" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/pekwm|' $1/etc/lxdm/lxdm.conf
	fi

	_displaymanager='lxdm'
    fi
    
    if [[ -e $1/usr/bin/openrc ]];then
	local _conf_xdm='DISPLAYMANAGER="'${_displaymanager}'"'
	sed -i -e "s|^.*DISPLAYMANAGER=.*|${_conf_xdm}|" $1/etc/conf.d/xdm
    fi
}

# $1: chroot
configure_accountsservice(){
    msg2 "Configuring AcooutsService ..."
    if [ -d "$1/var/lib/AccountsService/users" ] ; then
	echo "[User]" > $1/var/lib/AccountsService/users/${username}
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    echo "XSession=xfce" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    echo "XSession=cinnamon" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    echo "XSession=mate" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    echo "XSession=enlightenment" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    echo "XSession=openbox" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    echo "XSession=LXDE" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    echo "XSession=LXQt" >> $1/var/lib/AccountsService/users/${username}
	fi
	echo "Icon=/var/lib/AccountsService/icons/${username}.png" >> $1/var/lib/AccountsService/users/${username}
    fi
}

write_calamares_dm_conf(){
    # write the conf to overlay-image/etc/calamares ?
    local DISPLAYMANAGER="$1/etc/calamares/modules/displaymanager.conf"
    
    echo "displaymanagers:" > "$DISPLAYMANAGER"
    echo "  - ${_displaymanager}" >> "$DISPLAYMANAGER"
    echo '' >> "$DISPLAYMANAGER"
    echo '#executable: "startkde"' >> "$DISPLAYMANAGER"
    echo '#desktopFile: "plasma"' >> "$DISPLAYMANAGER"
    echo '' >> "$DISPLAYMANAGER"
    echo "basicSetup: false" >> "$DISPLAYMANAGER"
}

setup_live_installer(){
    if [ -e "/etc/live-installer/install.conf" ] ; then
      _conf_file="/etc/live-installer/install.conf"
    fi
}

setup_thus(){
    if [ -e "/etc/thus.conf" ] ; then
	_conf_file="/etc/thus.conf"
    fi

    if [ -e "$_conf_file" ] ; then
	sed -i "s|_root-image_|/bootmnt/${install_dir}/_ARCH_/root-image.sqfs|g" $_conf_file
	sed -i "s|_kernel_|$manjaro_kernel|g" $_conf_file
	release=$(cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d= -f2)
	sed -i "s|_version_|$release|g" $_conf_file

	if [ -e "/bootmnt/${install_dir}/${arch}/xfce-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/xfce-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro XFCE Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/gnome-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/gnome-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro Gnome Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/cinnamon-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/cinnamon-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro Cinnamon Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/openbox-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/openbox-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro Openbox Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/mate-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/mate-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro MATE Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/kde-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/kde-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro KDE Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxde-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/lxde-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro LXDE Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxqt-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/lxqt-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro LXQt Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/enlightenment-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/enlightenment-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro Enlightenment Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/pekwm-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/pekwm-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro PekWM Edition|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/custom-image.sqfs" ] ; then
	    sed -i "s|_desktop_|/bootmnt/${install_dir}/_ARCH_/custom-image.sqfs|g" $_conf_file
	    sed -i "s|_title_|Manjaro Custom Edition|g" $_conf_file
	fi
	if [ "${arch}" == "i686" ] ; then
	    sed -i "s|_ARCH_|i686|g" $_conf_file
	else
	    sed -i "s|_ARCH_|x86_64|g" $_conf_file
	fi
    fi
}

setup_calamares(){
    if [ -e "/usr/share/calamares/settings.conf" ] ; then
	_conf_file="/usr/share/calamares/modules/unpackfs.conf"
	sed -i "s|_root-image_|/bootmnt/${install_dir}/_ARCH_/root-image.sqfs|g" $_conf_file
	sed -i "s|_kernel_|$manjaro_kernel|g" "/usr/share/calamares/modules/initcpio.conf"

	if [ -e "/bootmnt/${install_dir}/${arch}/xfce-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/xfce-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/gnome-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/gnome-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/cinnamon-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/cinnamon-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/openbox-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/openbox-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/mate-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/mate-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/kde-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/kde-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxde-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/lxde-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxqt-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/lxqt-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/enlightenment-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/enlightenment-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/pekwm-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/pekwm-image.sqfs|g" $_conf_file
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/custom-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/custom-image.sqfs|g" $_conf_file
	fi
	if [ "${arch}" == "i686" ] ; then
	    sed -i "s|_ARCH_|i686|g" $_conf_file
	else
	    sed -i "s|_ARCH_|x86_64|g" $_conf_file
	fi
    fi
}
# $1: chroot
configure_calamares(){
    if [[ -f $1/usr/bin/calamares ]];then
	msg2 "Configuring Calamares ..."
	mkdir -p $1/etc/calamares/modules            
	local UNPACKFS="$1/usr/share/calamares/modules/unpackfs.conf"            
	if [ ! -e $UNPACKFS ] ; then                              
	    echo "---" > "$UNPACKFS"
	    echo "unpack:" >> "$UNPACKFS"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/root-image.sqfs\"" >> "$UNPACKFS"
	    echo "        sourcefs: \"squashfs\"" >> "$UNPACKFS"
	    echo "        destination: \"\"" >> "$UNPACKFS"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/${desktop}-image.sqfs\"" >> "$UNPACKFS"
	    echo "        sourcefs: \"squashfs\"" >> "$UNPACKFS"
	    echo "        destination: \"\"" >> "$UNPACKFS"                
	fi
	
	# TODO maybe add a configuration flag in manjaro-tools.conf for default displymanager
	
	#local DISPLAYMANAGER="$1/etc/calamares/modules/displaymanager.conf"
	
	write_calamares_dm_conf $1
	
	
# 	if [ ! -e $DISPLAYMANAGER ] ; then
# 	    echo "---" > "$DISPLAYMANAGER"
# 	    echo "displaymanagers:" >> "$DISPLAYMANAGER"
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/lightdm" ] ; then
# 		echo "  - lightdm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/share/config/kdm/kdmrc" ] ; then
# 		echo "  - kdm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/gdm" ] ; then
# 		echo "  - gdm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/mdm" ] ; then
# 		echo "  - mdm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/sddm" ] ; then
# 		echo "  - sddm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/lxdm" ] ; then
# 		echo "  - lxdm" >> "$DISPLAYMANAGER"
# 	    fi
# 	    if [ -e "${work_dir}/${desktop}-image/usr/bin/slim" ] ; then
# 		echo "  - slim" >> "$DISPLAYMANAGER"
# 	    fi   
# 	fi
	local INITCPIO="$1/usr/share/calamares/modules/initcpio.conf"
	if [ ! -e $INITCPIO ] ; then
	    echo "---" > "$INITCPIO"
	    echo "kernel: ${manjaro_kernel}" >> "$INITCPIO"
	fi  
    fi
}

