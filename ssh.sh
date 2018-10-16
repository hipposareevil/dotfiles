#!/bin/bash

# Sets the tab color
# Takes 3 params:
# red value
# green value
# blue value
#
# e.g. set_tab_color 255 255 0
function set_tab_color() {
    echo -ne "\033]6;1;bg;red;brightness;$1\a"
    echo -ne "\033]6;1;bg;green;brightness;$2\a"
    echo -ne "\033]6;1;bg;blue;brightness;$3\a"
}

function set_profile() {
  NAME=$1;
  if [ -z "$NAME" ]; then NAME="Default"; fi
  # set profile
  echo -e "\033]50;SetProfile=$NAME\a"

  # set tab color
#  set_tab_color 154 212 227
#  set_tab_color 200 23 43
}

# reset profile to Default
function reset_profile() {
    NAME="Default"
    # reset profile
    echo -e "\033]50;SetProfile=$NAME\a"
    # reset tab
#    echo -ne "\033]6;1;bg;*;default\a"

    # reset tab text
   echo -ne "\033]0;"Shell"\007"    
}

# check ssh params and change the profile
if [[ "$1" =~ (prod.oraclevcn) ]]; then
    set_profile "work.ssh.prod"
fi
if [[ "$1" =~ (dev.oraclevcn) ]]; then
    set_profile "work.ssh.dev"
fi
if [[ "$1" =~ (integ.oraclevcn) ]]; then
    set_profile "work.ssh.dev"
fi
if [[ "$1" =~ "willprogram" ]]; then
    set_profile "wpff"
fi

ssh "$@"

reset_profile
