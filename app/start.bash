#!/bin/bash

source /app/lib.bash

set -e

export SI_ADDRESS=${SI_ADDRESS:-192.168.1.2}
export SI_TMPFS_STAGING=${SI_TMPFS_STAGING:-n}
export DHCP_NEXT_SERVER=${DHCP_NEXT_SERVER:-${SI_ADDRESS}}
export DHCP_SUBNET_ADDRESS=${DHCP_SUBNET_ADDRESS:-192.168.1.0}
export DHCP_SUBNET_NETMASK=${DHCP_SUBNET_NETMASK:-255.255.255.0}
export DHCP_SUBNET_RANGE_START=${DHCP_SUBNET_RANGE_START:-192.168.1.10}
export DHCP_SUBNET_RANGE_END=${DHCP_SUBNET_RANGE_END:-192.168.1.250}
export DHCP_SUBNET_DOMAIN=${DHCP_SUBNET_DOMAIN}
export DHCP_SUBNET_GATEWAY=${DHCP_SUBNET_GATEWAY:-192.168.1.1}
export DHCP_BOOT_FILE=${DHCP_BOOT_FILE:-pxelinux.0}
export HTTP_PORT=${HTTP_PORT:-8989}

if [[ $SI_TMPFS_STAGING != y ]]; then
  export SI_TMPFS_STAGING=n
fi

function main {
  populate_volumes

  mkdir -p /run/php-fpm

  exec supervisord --user root --nodaemon --configuration=/app/supervisord.conf
}

function populate_volumes {
  populate_volume /app/files/etc_systemimager /etc/systemimager
  populate_volume /app/files/var_lib_systemimager /var/lib/systemimager

  read_config_env
  configure_httpd
  configure_rsyncd
  configure_dhcp
  configure_tftpd

  chmod 644 /etc/systemimager/systemimager.json
  chown apache /etc/systemimager/systemimager.json
}


function populate_volume {
  local src=$1
  local dest=$2

  if [[ -d "${dest}" ]] && [[ $(ls -A "${dest}" 2>/dev/null || true) ]]; then
    echo "Already populated ${dest}"
  else
    echo "Populating ${dest}"
    mkdir -p "${dest}"
    cp -a "${src}"/* "${dest}"
  fi
}


function configure_dhcp {
  local config=/etc/dhcp/dhcpd.conf
  local leases=/etc/dhcp/dhcpd.leases

  if [[ -s $config ]]; then
    echo "Using existing ${config}"
  else
    echo "Creating ${config}"
    env \
      | egrep '^(SI|DHCP|HTTP)_' \
      | sort

    mkdir -p /etc/dhcp
    envsubst < /app/templates/dhcpd.conf.envsubst > "${config}"
  fi

  if [[ ! -e $leases ]]; then
    touch "${leases}"
  fi
}


function configure_rsyncd {
  if [[ -s "${RSYNCD_CONF}" ]]; then
    echo "Using existing ${RSYNCD_CONF}"
  else
    echo "Creating ${RSYNCD_CONF}"
    si_mkrsyncd_conf
  fi
}


function configure_httpd {
  echo "Setting HTTP port"
  sed -r -i -e "s!^Listen .*!Listen ${HTTP_PORT}!" /etc/httpd/conf/httpd.conf
}


function configure_tftpd {
  if [[ -e /var/lib/tftpboot/linux.c32 ]]; then
    echo "Using existing /var/lib/tftpboot"
  else
    echo "Creating /var/lib/tftpboot"
    mkdir -p /var/lib/tftpboot
    cp -a /tftpboot/* /var/lib/tftpboot
    mkdir -p /var/lib/tftpboot/pxelinux.cfg
    si_mkbootserver -f
  fi
}

main "$@"
