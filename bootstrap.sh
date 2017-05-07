#!/bin/bash
# ----------------------------------------------------------------------
# Monero Miner Boostrapper for RHEL/Fedora Based Hosts v0.0.3
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

################################
#  USER CONFIGURATION OPTIONS  #
################################

# Pool Options - provide default values here, can be overridden
# by passing in values as arguments.
declare -r WALLET_ADDRESS="${1:-49mw3qFRFttFACrFSdtbM9XQrsnkyWr4ET9Sm9M3zGMud6AvfgJeMVJjWi1KB5jQUhajTpyJBasYKYZ1Rcrh6yvFR9CEkKv}"
declare -r POOL_ADDRESS="${2:-monerohash.com}"
declare -r POOL_PORT="${3:-3333}"

# No trailing slash unless root i.e. "/" or "/directory"
declare -r BIN_PREFIX="/usr"

# Get maximum number of supported cpu threads
declare -r MINER_THREADS=`$BIN_PREFIX/bin/grep -c ^processor /proc/cpuinfo`

################################
# DO NOT EDIT BEYOND THIS LINE #
################################

# When using Fedora >=22 switch to dnf for package management
declare PACKAGE_MANAGER="yum"
if [[ $(cat /etc/redhat-release | awk '{print $1;}') == "Fedora" && $(lsb_release -r -s) -ge "22" ]]; then

    PACKAGE_MANAGER="dnf"

fi

# Install build dependencies
function install_dependencies {

${BIN_PREFIX%/}/bin/$PACKAGE_MANAGER clean all && \
${BIN_PREFIX%/}/bin/$PACKAGE_MANAGER -y update && \
${BIN_PREFIX%/}/bin/$PACKAGE_MANAGER -y install git curl-devel && \
${BIN_PREFIX%/}/bin/$PACKAGE_MANAGER -y groupinstall "Development Tools" && \
${BIN_PREFIX%/}/bin/$PACKAGE_MANAGER clean all

}

# Compile the cpu miner executable and move into $PATH
function build_miner {

${BIN_PREFIX%/}/bin/git clone https://github.com/wolf9466/cpuminer-multi.git /usr/src/cpuminer-multi && \
cd /usr/src/cpuminer-multi && \
./autogen.sh && \
./configure CFLAGS="-march=native" --prefix=$BIN_PREFIX && \
${BIN_PREFIX%/}/bin/make && \
${BIN_PREFIX%/}/bin/make install

}

# Create self restarting systemd unit
function create_service {

${BIN_PREFIX%/}/bin/cat <<EOF > /etc/systemd/system/minerd.service
[Unit]
Description=Monero Miner Daemon
After=network.target

[Service]
TimeoutStartSec=0
ExecStart=${BIN_PREFIX%/}/bin/minerd -a cryptonight \
         -o stratum+tcp://$POOL_ADDRESS:$POOL_PORT \
         -u $WALLET_ADDRESS \
         -t $MINER_THREADS -p x
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

}

# Check for root privileges, if none exist escalate self using sudo.
if [ "$(id -u)" != "0" ]; then
    ${BIN_PREFIX%/}/bin/echo "This script must be run as root!"
    ${BIN_PREFIX%/}/bin/echo "Trying sudo..."
    ${BIN_PREFIX%/}/bin/sudo "$0" "$@"
    exit $?
fi

install_dependencies && \
${BIN_PREFIX%/}/bin/echo "Dependencies Installed!" && \

${BIN_PREFIX%/}/bin/sleep 3 && \

create_service && \
${BIN_PREFIX%/}/bin/echo "Systemd Unit File Created!" && \

${BIN_PREFIX%/}/bin/sleep 3 && \

build_miner && \
${BIN_PREFIX%/}/bin/echo "Miner Compiled Successfully!" && \

${BIN_PREFIX%/}/bin/sleep 3 && \

${BIN_PREFIX%/}/bin/systemctl daemon-reload && \
${BIN_PREFIX%/}/bin/systemctl enable minerd.service && \
${BIN_PREFIX%/}/bin/systemctl start minerd.service && \
${BIN_PREFIX%/}/bin/echo "Miner Service Enabled/Started!"
