#!/bin/bash

printf "\033[0;31mDisclaimer: This installer is unofficial and USB staff will not support any issues with it\033[0m\n"
read -p "Type confirm if you wish to continue: " input
if [ ! "$input" = "confirm" ]
then
    exit
fi

#Port-Picker by XAN & Raikiri
while [ -z "$port" ]
do
  app-ports show
  echo "Pick any application from the list above, that you're not currently using."
  echo "We'll be using this port for your second instance of Radarr"
  read -p "$(tput setaf 4)$(tput bold)Application name in full[Example: pyload]: $(tput sgr0)" appname
  proper_app_name=$(app-ports show | grep -i "$appname" | head -n 1 | cut -c 7-)
  port=$(app-ports show | grep -i "$appname" | head -n 1 | awk {'print $1'})
  if [ -z "$port" ]
  then
     echo "$(tput setaf 1)Invalid choice! Please choose an application from the list and avoid typos.$(tput sgr0)"
     echo "$(tput bold)Listing all applications again..$(tput sgr0)"
     sleep 5
     clear
  fi
done
echo "$(tput setaf 2)Are you sure you want to use $proper_app_name's port? type 'confirm' to proceed.$(tput sgr0)"
read -r input
if [ ! "$input" = "confirm" ]
then
  exit
fi

#Get radarr binaries
mkdir -p "$HOME"/.config/.temp; cd $_
wget -O "$HOME"/.config/.temp/radarr.tar.gz --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
if [[ $? -ne 0 ]]; then
    rm -rf "$HOME"/.config/.temp
    echo "Error: Binary download failed, try running the script again."
    exit 1; 
fi
tar -xvf radarr.tar.gz -C "$HOME/" && cd "$HOME"
sleep 5
mv "$HOME"/Radarr "$HOME"/.config/radarr2
rm -rf "$HOME"/.config/.temp

#Install nginx conf
echo 'location /radarr2 {
  proxy_pass        http://127.0.0.1:>port</radarr2;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Proto https;
  proxy_redirect off;

  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $http_connection;
}
  location /radarr2/api { auth_request off;
  proxy_pass       http://127.0.0.1:>port</radarr2/api;
}

  location /radarr2/Content { auth_request off;
    proxy_pass http://127.0.0.1:>port</radarr2/Content;
 }' > "$HOME/.apps/nginx/proxy.d/radarr2.conf"

sed  -i "s/>port</$port/g" "$HOME"/.apps/nginx/proxy.d/radarr2.conf

#Install Systemd service
cat << EOF | tee ~/.config/systemd/user/radarr.service > /dev/null
[Unit]
Description=Radarr Daemon
After=network-online.target
[Service]
Type=simple

ExecStart=%h/.config/radarr2/Radarr -nobrowser -data=%h/.apps/radarr2/
TimeoutStopSec=20
KillMode=process
Restart=always
[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now radarr.service
sleep 10

#Set radarr2 port
echo '<Config>
  <LogLevel>info</LogLevel>
  <UrlBase>/radarr2</UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <Branch>develop</Branch>
  <Port>temport</Port>
</Config>' > "$HOME/.apps/radarr2/config.xml"

sed -i "s/temport/$port/g" "$HOME"/.apps/radarr2/config.xml

systemctl --user restart radarr.service
app-nginx restart

echo ""
echo ""
echo "Installation complete."
echo "You can access it via https://$USER.$HOSTNAME.usbx.me/radarr2"
echo "Go to Settings -> General and setup authentication. Form login is recommended."
printf "\033[0;31mPlease do the above after first login!!! Failing to do so will keep your radarr2 instance open to public.\033[0m\n"

exit
