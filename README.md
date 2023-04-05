# Lib dispatch

A bash library to call function according to user input.

To build command line interface even better than git.

# Quickstart

Write file test.sh

```bash
#!/usr/bin/env bash

[[ ! -r ./lib_dispatch.sh ]] && curl https://raw.githubusercontent.com/tinmarino/lib_dispatch/main/script/lib_dispatch.sh -o lib_dispatch.sh
source ./lib_dispatch.sh

my_function(){
  : 'docstring of my function'
  echo "You called my function with $1"
  return 0
}

__complete_my_function(){
  : 'Autocompletion results'
  echo '
    my_param : dummy parameter to my function
    your_param : come on
    our_param : let share
  '
  
  # Consumes one parameters
  return 1
}


if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi
```

```bash
chmod +x test.sh
complete -o nosort -C ./test.sh ./test.sh  # Add completion to you shell
./test.sh  # Time to play
./test.sh my_function
```

# Details

Include me, declare some user functions and then call:

| Function            | Description |
| ---                 | --- |
| dipatch             | call at end of script |
| register_subcommand | call to register a subcommand |
| __default           | autocalled if no argument |
| __at_init           | autocalled before |
| __at_finish         | autocalled after |
| __set_env           | autoparsed for documentation, call it yourself |
| __complete_toto     | autocalled when completing toto function |

This interecting file is [lib_dispatch.sh](./script/lib_dispatch.sh).

TODO some documentation on my personal page or here in doc.
