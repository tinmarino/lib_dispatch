#!/usr/bin/env bash

main(){
  opts=(
    --include-path=dispatch,script
    --exclude-line=": ',--,  \",done"
  )
  kcov  coverage1 "${opts[@]}" dispatch util unit_test
  kcov --merge "${opts[@]}" coverage coverage1
  rm -r coverage1
}

if ! (return 0 2>/dev/null); then
  >&2 echo "--> $0 starting with $*."
  main "$@"; res=$?
  >&2 echo "<-- $0 returned with $res."
  exit "$res"
fi
