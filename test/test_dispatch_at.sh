#!/usr/bin/env bash
# Dispatch for dispatch bin have a --at option
# this is slow so in an other file / test job

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"
: "${cpurple:=}" "${cend:=}"


fingerprint(){
  echo -e "\n\n${cpurple}SSH$cend"
  tail -n +1 ~/.ssh/*

  echo -e "\n\n${cpurple}ENV$cend"
  env

  echo -e "\n\n${cpurple}SSH conf$cend"
  tail -n +1 /etc/ssh/sshd_config
}

# Prepare
install_ssh_ubuntu(){
  fingerprint

  sudo apt install openssh-server
  sudo systemctl enable ssh
  [[ -d ~/.ssh ]] || mkdir ~/.ssh 
  [[ -f ~/.ssh/id_rsa ]] && unlink ~/.ssh/id_rsa
  [[ -f ~/.ssh/known_hosts ]] && chmod 600 ~/.ssh/known_hosts
  # From: https://stackoverflow.com/questions/43235179/how-to-execute-ssh-keygen-without-prompt
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
  echo "PermitRootLogin without-password" | sudo tee -a /etc/ssh/sshd_config
  #ssh-copy-id localhost
  #ssh-copy-id "$USER@$HOSTNAME"
  sudo systemctl restart ssh

  fingerprint
}


myos=$(get_os)

# Clause: work only on Linux
if [[ linux != "$myos" ]]; then
  pinfo "Exiting <= not linux OS => no ssh"
  exit 0
fi

# Must install ssh on github cloud (I guess)
if [[ -v GITHUB_ACTION ]]; then
  #install_ssh_ubuntu
  # TODO cannot ssh to self
  exit 0
fi


start_test_function "dispatch --at (via dispatch)"
  # Test return status
  bash_timeout 2 "$gs_root_path"/dispatch --at localhost example fail &> /dev/null
  equal 42 $? "--at: Return Status: Command: dispatch --at localhost example fail: should return status 42" \
    --desc "Command should return my failure <= This proves that the exit status is well transmitted with the --at option" \
    --tip "Run: 'ssh localhost' <= Maybe you cannot connect to ssh" \
    --tip "Run: 'ssh-keygen -t rsa' <= You must a key pair if above command failed with: ssh-copy-id no identities found error" \
    --tip "Run: 'ssh-copy-id localhost' <= You do not want to type password everytime" \
    --tip "Run: 'sudo systemctl status ssh' <= Maybe ssh service is not running" \
    --tip "Run: 'sudo systemctl enable ssh' <= Maybe ssh service is not enabled" \
    --tip "Run: 'sudo apt install openssh-server' <= Maybe ssh service is not installed"

  bash_timeout 1 "$gs_root_path"/dispatch --at localhost example succeed &> /dev/null
  equal 0 $? "--at: Return Status: Command: dispatch --at localhost example succeed: should succeed" \
    --desc "Command should return success"

  bash_timeout 1 "$gs_root_path"/dispatch --at "${USER:-$USERNAME}@localhost" example fail &> /dev/null
  equal 42 $? "--at: with username: command: dispatch --at ${USER:-$USERNAME}@localhost example fail: should return 42" \
    --desc "Command should return my failure"

  bash_timeout 1 "$gs_root_path"/dispatch --at "${USER:-$USERNAME}@$HOSTNAME" example fail &> /dev/null
  equal 42 $? "--at: dispatch --at ${USER:-$USERNAME}@$HOSTNAME example fail" \
    --desc "Command should return my failure (at USER@HOSTNAME)" \
    --tip "Run: 'ssh-copy-id ${USER:-$USERNAME}@$HOSTNAME' <= You do not want to type password everytime" \
    --tip "Run: 'vim /etc/hostname /etc/hosts'"

  # Unreachable target computer
  # -- Timeout > 1 in case the ssh timeout to unreach is set to 1 sec (default i guess)
  out=$(bash_timeout 2 "$gs_root_path"/dispatch --at totototo example fail 2> /dev/null)
  equal "$E_ARG" $? "dispatch --at tototototo example fail" \
    --desc "Command should fail with status=E_ARG if given an unreachable server as parameter (here totototot)"
  equal "" "$out" "Previous command (with unreachable server) should have no stdout, only perr used"

  # Unknown command
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
