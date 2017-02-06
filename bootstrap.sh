#!/bin/bash
# ----------------------------------------------------------------------
# Monero Miner Boostrapper for RHEL Based Hosts v0.0.1
# ----------------------------------------------------------------------
# Copyright (C) 2017 Dominic Robinson
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ----------------------------------------------------------------------

# Custom Options
declare -r WALLET_ADDRESS=`[[ -z "$1" ]] && echo "41h7QyCBwVFU4mWxRjjDAC3yDvuA6rjxcJ2PhcEL6KTMfvDnxr2nzaw4LnfYhmJgCVQJJG6tPJJntGwRq77fcjcW2zh1rYg" || echo "$1"`
declare -r POOL_ADDRESS=`[[ -z "$2" ]] && echo "monerohash.com" || echo "$2"`
declare -r POOL_PORT=`[[ -z "$3" ]] && echo "3333" || echo "$3"`

# Distro Specififc
declare -r BIN_PREFIX="/usr"
declare -r MINER_THREADS=`$BIN_PREFIX/bin/grep -c ^processor /proc/cpuinfo`

function install_dependencies {

$BIN_PREFIX/bin/yum clean all && \
$BIN_PREFIX/bin/yum -y update && \
$BIN_PREFIX/bin/yum -y install git curl-devel && \
$BIN_PREFIX/bin/yum -y groupinstall "Development Tools" && \
$BIN_PREFIX/bin/yum clean all

}

function build_miner {

$BIN_PREFIX/bin/git clone https://github.com/wolf9466/cpuminer-multi.git /usr/src/cpuminer-multi && \
cd $BIN_PREFIX/src/cpuminer-multi && \
./autogen.sh && \
./configure CFLAGS="-march=native" --prefix=$BIN_PREFIX && \
$BIN_PREFIX/bin/make && \
$BIN_PREFIX/bin/make install

}

function create_service {

$BIN_PREFIX/bin/cat <<EOF > /etc/systemd/system/minerd.service
[Unit]
Description=Monero Miner Daemon
After=network.target

[Service]
TimeoutStartSec=0
ExecStart=$BIN_PREFIX/bin/minerd -a cryptonight \
         -o stratum+tcp://$POOL_ADDRESS:$POOL_PORT \
         -u $WALLET_ADDRESS \
         -t $MINER_THREADS -p x
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

}

if [ "$(id -u)" != "0" ]; then
    $BIN_PREFIX/bin/echo "This script must be run as root!"
    $BIN_PREFIX/bin/echo "Trying sudo..."
    $BIN_PREFIX/bin/sudo "$0" "$@"
    exit $?
fi

install_dependencies && \
$BIN_PREFIX/bin/echo "Dependencies Installed!" && \

build_miner && \
$BIN_PREFIX/bin/echo "Miner Compiled Successfully!" && \

create_service && \
$BIN_PREFIX/bin/echo "Systemd Unit File Created!" && \

$BIN_PREFIX/bin/systemctl daemon-reload && \
$BIN_PREFIX/bin/systemctl enable minerd.service && \
$BIN_PREFIX/bin/systemctl start minerd.service && \
$BIN_PREFIX/bin/echo "Miner Service Enabled/Started!"
