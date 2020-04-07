CONFIG_ENV=/etc/systemimager/systemimager.conf
CONFIG_JSON=/etc/systemimager/systemimager.json

function config_env_bash {
  sed -re 's!#.*!!' /etc/systemimager/systemimager.conf \
    | egrep -v '^[[:space:]]*$' \
    | sed -re 's![[:space:]]*=[[:space:]]*!=!' \
    | sed -re 's!^!export !'
}

function read_config_env {
  export NET_BOOT_DEFAULT=net
  export RSYNCD_CONF=/etc/systemimager/rsyncd.conf

  source <(config_env_bash)
}

function wait_for_file {
  while [[ ! -e $1 ]]; do
    echo "Waiting for $1 to be created"
    sleep 1
  done
}

function kill_pid {
  local pid=$1

  if [[ $pid ]]; then
    while [[ -e /proc/$pid ]]; do
      kill -9 "${pid}"
      sleep 1
    done
  fi
}


function kill_pidfile {
  local pidfile=$1

  if [[ -s $pidfile ]]; then
    read pid < "${pidfile}"
    kill_pid "${pid}"
  fi
}

function add_file {
  local src=$1
  local dest=$2

  if [[ ! -s $dest ]]; then
    cp -v "${src}" "${dest}"
  fi
}
