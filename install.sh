#!/bin/bash

G='\033[0;32m'
Y='\033[0;33m'
NC='\033[0m'

printf "\n"
printf " ... Please wait for a few seconds ...\n"
printf "\n"

CHECK_OS="$(awk '/^ID=/' /etc/*os-release | awk -F'=' '{ print tolower($2) }')"

if [ "${CHECK_OS}" = "debian" ] || [ "${CHECK_OS}" = "\"debian\"" ] || [ "${CHECK_OS}" = "ubuntu" ] || [ "${CHECK_OS}" = "\"ubuntu\"" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update
    DEBIAN_FRONTEND=noninteractive apt-get -y -qq install apache2-utils squid3 wget 1>/dev/null 2>/dev/null
elif [ "${CHECK_OS}" = "fedora" ] || [ "${CHECK_OS}" = "\"fedora\"" ]; then
    dnf -y install httpd-tools squid3 wget 1>/dev/null 2>/dev/null
elif [ "${CHECK_OS}" = "centos" ] || [ "${CHECK_OS}" = "\"centos\"" ]; then
    yum install -y httpd-tools squid3 wget 1>/dev/null 2>/dev/null
fi

PROXY_USER="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
PROXY_PASS="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
PROXY_IP="$(wget http://ipecho.net/plain -O - -q)"
PROXY_PORT="5$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1)$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1)$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1)$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1)"

SQUID_DIR="/etc/squid"
SQUID_LIB="/usr/lib/squid"

if [ ! -d "${SQUID_DIR}" ]; then
    SQUID_DIR="/etc/squid3"
fi

if [ ! -d "${SQUID_LIB}" ]; then
    SQUID_LIB="/usr/lib/squid3"
fi

if [ ! -f "${SQUID_DIR}/passwd" ]; then
    touch "${SQUID_DIR}/passwd"
fi

echo "${PROXY_PASS}" | htpasswd -i "${SQUID_DIR}/passwd" "${PROXY_USER}" 1>/dev/null 2>/dev/null

touch "${SQUID_DIR}/squid.conf.new"

cat <<EOT >> "${SQUID_DIR}/squid.conf.new"
http_port ${PROXY_PORT}
auth_param basic program ${SQUID_LIB}/basic_ncsa_auth ${SQUID_DIR}/passwd
auth_param basic children 5
auth_param basic realm Squid Basic Authentication
auth_param basic credentialsttl 2 hours
acl auth_users proxy_auth REQUIRED
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Proxy deny all
request_header_access Cache-Control deny all
http_access allow auth_users
EOT

cat "${SQUID_DIR}/squid.conf" >> "${SQUID_DIR}/squid.conf.new"

mv "${SQUID_DIR}/squid.conf.new" "${SQUID_DIR}/squid.conf"

systemctl start squid3 1>/dev/null 2>/dev/null
systemctl enable squid3 1>/dev/null 2>/dev/null
systemctl restart squid3 1>/dev/null 2>/dev/null

systemctl start squid 1>/dev/null 2>/dev/null
systemctl enable squid 1>/dev/null 2>/dev/null
systemctl restart squid 1>/dev/null 2>/dev/null

printf "${Y}----------------------------------------${NC}\n"
printf "${G}YOUR PROXY - ${PROXY_USER}:${PROXY_PASS}@${PROXY_IP}:${PROXY_PORT}\n"
printf "${Y}----------------------------------------${NC}\n"
printf "\n"
