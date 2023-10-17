#!/usr/bin/env bash

setup(){
  # Declare variables
  local bin_dir="$HOME"/.local/bin
  local lib_dir="$HOME"/.local/lib
  local install_dir="$lib_dir"/lib_dispatch
  local git_remote=https://github.com/tinmarino/lib_dispatch
  local title=LibDispatch

  # Create required directories
  mkdir -p "$bin_dir"
  mkdir -p "$lib_dir"
  [[ -e "$install_dir" ]] && unlink "$install_dir"
  
  >&2 echo "[i] $title: Removing potential last install at $install_dir"
  [[ -e "$install_dir" ]] && rm -rf "$install_dir"

  >&2 echo "[i] $title: Cloning git from: $git_remote, to $install_dir"
  git clone "$git_remote" "$install_dir"

  >&2 echo "[i] $title: Symlinking to $bin_dir/lib_dipatch.sh"
  ln -s "$install_dir/script/lib_dispatch.sh" "$bin_dir/lib_dipatch.sh"

  >&2 echo "[i] $title: Symlinking to $bin_dir/lib_dipatch.sh"
  ln -s "$install_dir/script/lib_misc.sh" "$bin_dir/lib_misc.sh"

  >&2 echo
  >&2 echo "SUCCESS: please run or source lib_dispatch.sh"
}


if ! (return 0 2>/dev/null); then
  >&2 echo "--> $0 starting with $*."
  setup "$@"; res=$?
  >&2 echo "<-- $0 returned with $res."
  exit "$res"
fi
