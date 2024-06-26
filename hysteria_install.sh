#!/bin/bash

set -euxo pipefail
trap 'echo "Error on line $LINENO"' ERR

if [[ "$USER" = 'root' ]];then
  echo 'install sequence starts...'
else
  echo 'please execute this script with user of sudo priviliges'
  exit 1
fi
  if [[ $(uname -m 2> /dev/null) != "x86_64" ]]; then
    echo "sorry, CPU architecture does not meet requirements..."
    exit 1
  fi

PASSWORD=""

while getopts p: opt; do
  case $opt in
    p) PASSWORD=$OPTARG ;;
    *) echo 'No password assigned...'
  esac
done

if [[ -z "$PASSWORD" ]]; then
  echo 'generate a random password...'
#  PASSWORD="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 10 | head -n 1)"
  PASSWORD=$(openssl rand -base64 8)
fi

# generate a self-sign certficate
if [[ ! -d "/etc/hysteria/" ]]; then
  mkdir /etc/hysteria/
fi
  if [[ ! -d "/var/log/hysteria/" ]]; then
    mkdir /var/log/hysteria/
  fi

TEMPEDC=$(mktemp)
openssl ecparam -name prime256v1 -out "$TEMPEDC" 2> /var/log/hysteria/error.log
openssl req -x509 -nodes -newkey ec:"$TEMPEDC" -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj '/CN=bing.com' -days 36500 2> /var/log/hysteria/error.log


# run install script
wget https://get.hy2.sh/ -O _install.sh
chmod +x _install.sh && ./_install.sh >&2
chown hysteria /etc/hysteria/server.key && chown hysteria /etc/hysteria/server.crt


cat <<EOF > /etc/hysteria/config.yaml
# listen: :443

tls:
 cert: /etc/hysteria/server.crt
 key: /etc/hysteria/server.key

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://zhihu.com/
    rewriteHost: true
EOF

# start hysteria service
systemctl start hysteria-server.service
systemctl enable hysteria-server.service
clear

IPADDRESS=$(curl ifconfig.me)
echo "server: $IPADDRESS"
echo "password: $PASSWORD"



