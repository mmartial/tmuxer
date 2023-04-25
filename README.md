# tmuxer

(Tool in development)

Short shell script to take a set of commands and run them in parallel using `tmux`

```
./tmuxer.sh tmuxfile directory_with_executables logs_directory
```

The tool:
- creates a `tmuxfile` script (bash script)
  - it will refuse to run if the script already exists
- will only use executable programs from the `directory_with_executables`
- will create the `logs_directory` and create files in there using the tmux window id, the executable name, and a `.log` extension
  - it will refuse to run if the directory already exists
- requires `script` and `tmux` to be installed on the host
  - the tool will check for their existence and fail if either is not present
  - because of variations in the version of the base tools, this tool was only tested on Linux and will only accept to run on this plaform

## Example of use

Let's create a basic shell script in a `torun` directory name `scr1` (needs `fortune` installed)

```
#!/bin/bash
fortune
t=$[ ( $RANDOM % 10 )  + 1 ]
sleep ${t}s
```

Let's copy it to `scr2`, `scr3`, and `scr4`

```
$ cp torun/scr{1,2,3,4}
```

Let's make `scr1`, `scr2` and `scr3` executable (we are keeping `src4` non executable for demonstration purpose)

```
$ chmod u+x torun/scr{1,2,3}
```

Let's run the script to get our base script:

```
$ ./tmuxer.sh torun.tmux torun logs
[**] Confirming executable files list from torun
  [OK] scr1
  [OK] scr2
  [OK] scr3
  [--] scr4 is not a file/executable, skipping
[**] Writing output file: torun.tmux
  [++] Added scr1
  [++] Added scr2
  [++] Added scr3
Done
```

The generated script is fairly simple:

```
$ cat ./torun.tmux
#!/bin/bash

/usr/bin/tmux new-session -d -s torun_tmux 'echo "tmux started, this window will close in 10 seconds"; sleep 10'
/usr/bin/tmux new-window -t torun_tmux: -n '1-scr1' '/usr/bin/script -e -O "logs/1-scr1.log" -c "torun/scr1"'
/usr/bin/tmux new-window -t torun_tmux: -n '2-scr2' '/usr/bin/script -e -O "logs/2-scr2.log" -c "torun/scr2"'
/usr/bin/tmux new-window -t torun_tmux: -n '3-scr3' '/usr/bin/script -e -O "logs/3-scr3.log" -c "torun/scr3"'
/usr/bin/tmux attach-session -t torun_tmux

```

We can now run `./torun.tmux` and wait for all the scripts to run in parallel and complete. 
When they are all complete, you will get back to your shell prompt after a `tmux` `[exited]` message. 
The script logs are stored in the `logs` directory. 
Each `log` file should have a `[COMMAND_EXIT_CODE="0"]` in the last line, which can be used to confirm that the scripts ended succesfully.
