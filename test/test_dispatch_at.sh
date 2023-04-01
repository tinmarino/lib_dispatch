#!/usr/bin/env bash
# Dispatch for dispatch bin have a --at option
# this is slow so in an other file / test job

# Source test utilities
  export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
  gs_root_path="$(dirname "$gs_root_path")"
  gs_root_path="$(dirname "$gs_root_path")"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"


# Prepare
set_ssh_ubuntu(){
  sudo apt install openssh-server
  sudo systemctl enable ssh
  ssh-copy-id localhost
}


get_os(){
  # shellcheck disable=SC2088
  uname=$(uname -a)
  uname=${uname,,}
  case $uname in
  *"android"*)
    export os="termux"
    export v="$HOME/.vim"
    ;;
  *"linux"*)
    export os="unix"
    export v="$HOME/.vim"
    ;;
  *"mingw"*)
    export os="windows"
    export v="$HOME/vimfiles"
    ;;
  *)
    export os="unknown"
    export v="$HOME/.vim"
    ;;
  esac
  echo "$os"
}

myos=$(get_os)

# Clause: work only on Linux
if [[ unix != "$myos" ]]; then
  pinfo "Exiting <= not linux OS => no ssh"
  exit 0
fi


start_test_function "dispatch --at (via dispatch)"
  bash_timeout 2 "$gs_root_path"/dispatch --at localhost example fail &> /dev/null
  equal 42 $? "dispatch --at localhost example fail" \
    --desc "Command should return my failure <= This prooves that the exit status is well transmited with the --at option" \
    --tip "Run: 'ssh localhost' <= Maybe you cannot connect to ssh" \
    --tip "Run: 'ssh-copy-id localhost' <= You do not want to type password everytime" \
    --tip "Run: 'sudo systemctl status ssh' <= Maybe ssh service is not running" \
    --tip "Run: 'sudo systemctl enable ssh' <= Maybe ssh service is not enabled" \
    --tip "Run: 'sudo apt install openssh-server' <= Maybe ssh service is not installed"

  bash_timeout 1 "$gs_root_path"/dispatch --at localhost example succeed &> /dev/null
  equal 0 $? "dispatch --at localhost example succeed" \
    --desc "Command should return success"

  bash_timeout 1 "$gs_root_path"/dispatch --at "$USER@localhost" example fail &> /dev/null
  equal 42 $? "dispatch --at $USER@localhost example fail" \
    --desc "Command should return my failure"

  bash_timeout 1 "$gs_root_path"/dispatch --at "$USER@$HOSTNAME" example fail &> /dev/null
  equal 42 $? "dispatch --at $USER@$HOSTNAME example fail" \
    --desc "Command should return my failure (at USER@HOSTNAME)" \
    --tip "Run: 'ssh-copy-id $USER@$HOSTNAME' <= You do not want to type password everytime" \
    --tip "Run: 'vim /etc/hostname /etc/hosts'"

  # Unreachable target computer
  # -- Timeout > 1 in case the ssh timeout to unreach is set to 1 sec (default i guess)
  out=$(bash_timeout 2 "$gs_root_path"/dispatch --at totototo example fail 2> /dev/null)
  equal "$E_ARG" $? "dispatch --at tototototo example fail" \
    --desc "Command should fail with status=E_ARG if given an unreachable server as parameter (here totototot)"
  equal "" "$out" "Previous command (with unreachable server) should have no stdout, only perr used"

  # Unkown command
  out=$(bash_timeout 1 "$gs_root_path"/dispatch --at localhost totototo 2> /dev/null)
  equal "$E_ARG" $? "dispatch --at localhost totototo" \
    --desc "Command should fail with wrong args (E_ARG) <= given an unknown subcommand"
  equal "" "$out" "Command above (wrong subcmd) bove should have no stdout"

  # No argument
  out=$(bash_timeout 1 "$gs_root_path"/dispatch --at localhost 2> /dev/null)
  equal 0 $? "dispatch --at localhost  # status" \
    --desc "without subcmd status should be zero"
  [[ "$out" =~ example ]]
  equal 0 $? "dispatch --at localhost  # Stdout example" \
    --desc "without subcmd should print the example subcmd"
  [[ "$out" =~ "Example dummy" ]]
  equal 0 $? "dispatch --at localhost  # Stdout 2 desc" \
    --desc "without subcmd should print the example subcmd comment"


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
