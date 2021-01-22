#!/bin/bash
# exit when any command fails
set -e

echo "Chuong  trinh cai dat nen tang Edge AI - IVIEW.VN"


DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND=noninteractive

print_style () {

    if [ "$2" == "info" ] ; then
        COLOR="96m";
    elif [ "$2" == "success" ] ; then
        COLOR="92m";
    elif [ "$2" == "warning" ] ; then
        COLOR="93m";
    elif [ "$2" == "danger" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR" "$1";
}


printf "=========================================================================\n"
print_style "Kiem tra he thong \n" "info";
printf "=========================================================================\n"


if [ "$EUID" -ne 0 ]; then
        echo "Ban can chay chuong trinh bang quen root"
echo "--------------------------------------------------------------"

		exit 1

	fi

if [[ -z "$(cat /etc/resolv.conf)" ]]; then
	echo ""
	echo "/etc/resolv.conf is empty. No nameserver resolvers detected !! "
	echo "Please configure your /etc/resolv.conf correctly or you will not"
	echo "be able to use the internet or download from your server."
	echo "aborting script... please re-run install"
	echo ""
	exit 1
fi


cat << EOF > /etc/hosts
127.0.0.1       localhost
10.8.0.1   iview.central

EOF

cat << EOF > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p

touch /var/local/status.txt
chown root:root /var/local/status.txt
chmod 666 /var/local/status.txt

printf "=========================================================================\n"
print_style "Cap nhat he thong \n" "info";
printf "=========================================================================\n"

apt-get update
apt install -y chrony openvpn wget unzip nginx
apt install -y xorg
apt  install -f fonts-liberation  libnotify-bin notify-osd
apt install -y ifupdown net-tools
systemctl enable networking
systemctl start networking
apt-get install -y dialog apt-utils
apt-get install -y libpam-kwallet4 libpam-kwallet5 libpam-winbind
mkdir /usr/share/xsessions

systemctl stop NetworkManager  
systemctl disable NetworkManager 

printf "=========================================================================\n"
printf "=========================================================================\n"


printf "=========================================================================\n"
print_style "Cai dat docker  \n" "info";
printf "=========================================================================\n"


apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common 

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get install -y docker-ce docker-ce-cli containerd.io 
cat <<EOF> /etc/docker/daemon.json
{
          "default-runtime": "nvidia",
         "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "dns": ["8.8.8.8", "8.8.4.4"]

}
EOF

systemctl restart docker  
systemctl enable docker 



print_style "OK \n" "success";

printf "=========================================================================\n"
print_style "Cai dat IVIEW agent  \n" "info";
printf "=========================================================================\n"

wget https://github.com/rancher/k3s/releases/download/v1.16.13%2Bk3s1/k3s-arm64
mv k3s-arm64 /usr/local/bin/k3s 
chmod +x /usr/local/bin/k3s 

print_style "OK \n" "success";

printf "=========================================================================\n"
print_style "Cau hinh che do hien thi  \n" "info";
printf "=========================================================================\n"


apt-get install -y dialog apt-utils  
apt-get install -y libpam-kwallet4 libpam-kwallet5 libpam-winbind  
apt-get install -y chromium-browser

if [ -d "/usr/share/xsessions" ] 
then
    echo ""
else
    mkdir /usr/share/xsessions 
fi

launch_dir=`pwd`
readonly START_TIME=`date +%Y-%m-%dT%H:%M:%S`
readonly LOG_DIR="logs"
readonly LOG_FILE="build_$START_TIME.log"
readonly LOG_OUT="$launch_dir/$LOG_DIR/$LOG_FILE"

readonly KIOSK_DESKTOP_RC="\
[Desktop]\n\
Session=kiosk\n"

readonly KIOSK_AUTOLOGIN="\
[Seat:*]\n\
allow-guest=false\n\
greeter-hide-users=true\n\
autologin-guest=false\n\
autologin-user=kiosk\n\
autologin-user-timeout=0\n"

readonly KIOSK_DEFAULT_SESSION="\
[Seat:*]\n\
user-session=kiosk\n"

readonly KIOSK_XSESSION="\
[Desktop Entry]\n\
Type=Application\n\
Encoding=UTF-8\n\
Name=Kiosk\n\
Comment=Start a Chrome-based Kiosk session\n\
Exec=/home/kiosk/start-chrome.sh\n\
Icon=google=chrome"

###############################################################################

# Configuration steps
do_install_chrome=y
do_create_kiosk_user=y
do_create_kiosk_xsession=y
do_enable_kiosk_autologin=y
do_write_chrome_startup=y

###############################################################################

msg() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)]: $@" >&2
}

###############################################################################

create_kiosk_user() {
    msg "Creating IVIEW group and user"
    getent group kiosk || (
        groupadd kiosk
        useradd kiosk -s /bin/bash -m -g kiosk -p '*'
        passwd -d kiosk # Delete kiosk's password
        # Lock kiosk's account so that kiosk can't login using SSH or by
        # switching tty. However, lightdm can still start a session with this
        # user
        passwd -l kiosk
    )
}

###############################################################################

create_kiosk_xsession() {
    msg "Creating IVIEW Xsession"
    echo -e $KIOSK_XSESSION > /usr/share/xsessions/kiosk.desktop
}

###############################################################################

install_chrome() {
    msg "Installing IVIEW Display"
    apt-get install -y chromium-browser lightdm 
    
}

###############################################################################

enable_kiosk_autologin() {
    msg "Enabling IVIEW autologin"
    echo -e $KIOSK_AUTOLOGIN > /etc/lightdm/lightdm.conf
    echo -e $KIOSK_DEFAULT_SESSION > /etc/lightdm/lightdm.conf.d/99-kiosk.conf
}

###############################################################################

write_chrome_startup() {
    msg "Writing IVIEW page"
    touch /home/kiosk/start-chrome.sh
    chown kiosk:kiosk /home/kiosk/start-chrome.sh
    chmod +x /home/kiosk/start-chrome.sh
}

###############################################################################
# Start execution
###############################################################################

# Provide an opportunity to stop installation
msg "Configure Display"

if [ $do_install_chrome = "y" ]; then
    install_chrome
fi

if [ $do_create_kiosk_user = "y" ]; then
    create_kiosk_user
fi

if [ $do_create_kiosk_xsession = "y" ]; then
    create_kiosk_xsession
fi

if [ $do_enable_kiosk_autologin = "y" ]; then
    enable_kiosk_autologin
fi

if [ $do_write_chrome_startup = "y" ]; then
    write_chrome_startup
fi


echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg-reconfigure lightdm
echo set shared/default-x-display-manager lightdm | debconf-communicate

print_style "OK \n" "success";



printf "=========================================================================\n"
print_style "Cau hinh IVIEW package  \n" "info";
printf "=========================================================================\n"

rm -rf /tmp/iedge /tmp/iedge.zip 
rm -rf /var/www/html/*
wget https://github.com/Edge-IVIEW/iEdge/releases/download/0.1/iedge.zip -O /tmp/iedge.zip 
unzip /tmp/iedge.zip -d /tmp/iedge 
mv /tmp/iedge/register.zip /var/www/html/
unzip /var/www/html/register.zip  -d /var/www/html/ 
mv /tmp/iedge/webregister /usr/bin/webregister

chmod +x /home/kiosk/start-chrome.sh

cat <<EOF> /etc/nginx/sites-available/default
server {
        listen 3000 default_server;
        root /var/www/html;
        server_name _;

        location / {
        }
}
EOF

systemctl start nginx
systemctl enable nginx

cat <<EOF> /usr/bin/webregister.env
#server
ListenBackend="0.0.0.0:5055" 
RateLimitBackend=15

ENVBackend="env" 

#front end
BrowserBackend="$(pwd)/dashboard"

#log
ErrorLog="errorLog" 
AccessLogPath="accessLog" 

EOF


cat <<EOF> /etc/systemd/system/webregis.service
[Unit]
Description=Init Web register
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
User=root
EnvironmentFile=/usr/bin/webregister.env
ExecStart=/usr/bin/webregister

[Install]
EOF

print_style "OK \n" "success";


printf "=========================================================================\n"
print_style "Cap nhat Docker base  \n" "info";
printf "=========================================================================\n"
chown kiosk:kiosk -R .

echo 'kiosk ALL=(ALL) NOPASSWD: ALL' | sudo tee -i /etc/sudoers.d/kiosk
chown kiosk:kiosk /home/kiosk -R .
chown kiosk:kiosk /home/kiosk -R *

print_style "OK \n" "success";


printf "=========================================================================\n"
print_style "Cau hinh start chrome \n" "info";
printf "=========================================================================\n"

cat <<EOF>/home/kiosk/start-chrome.sh

#!/bin/bash

export DISPLAY=:0


X_RES=`xrandr | grep "*" | awk -Fx '{ print $1 }' | sed 's/[^0-9]*//g'`
Y_RES=`xrandr | grep "*" | awk -Fx '{ print $2 }' | awk '{ print $1 }'`

# Prevents screen blanking
xset s off
xset s noblank
xset -dpms

gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0


# NVIDIA CUDA Toolkit
export PATH=/usr/local/cuda-10.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/aarch64-linux-gnu

sudo systemctl start docker


while ! ping -c 1 -W 1 iedge.iview.vn; do

    DISPLAY=:0 notify-send "Trying connect to IVIEW"

        sleep 5
done



device_status=`sudo cat /var/local/status.txt`

if [ "$device_status" == "registed" ]; then
    DISPLAY=:0 notify-send "Trying to open exists app"
    sudo systemctl start iedge-agent

    while ! curl http://localhost:5007; do
      echo "Waiting for backend core start"
    done
    chromium-browser --disk-cache-dir=/dev/null --no-sandbox --disable-features=TranslateUI --disable-infobars --disable-translate --no-first-run --noerrdialogs --start-fullscreen --app=http://localhost:80 --user-data-dir=/home/kiosk/.chromium --disable-notifications --window-position=0,0 --window-size=$X_RES,$Y_RES --full-screen --incognito --kiosk


else
    DISPLAY=:0 notify-send "Trying to open regiser app"

    sudo systemctl start webregis
    while ! curl http://localhost:5055; do
      echo "Waiting for backend core start"
    done
    chromium-browser --disk-cache-dir=/dev/null --no-sandbox --disable-features=TranslateUI --disable-infobars --disable-translate --no-first-run --noerrdialogs --start-fullscreen --app=http://localhost:3000 --user-data-dir=/home/kiosk/.chromium --disable-notifications --window-position=0,0 --window-size=$X_RES,$Y_RES --full-screen --incognito --kiosk

    echo "Thiet bi chua duoc dang ky"


fi


EOF




printf "=========================================================================\n"
print_style "Qua trinh cai dat thanh cong. Vui long khoi dong lai device  \n" "info";
printf "=========================================================================\n"



exit

###############################################################################
# End execution
###############################################################################












