#!/bin/bash

usage () {
  echo "$0 tmuxfile directory_with_executables logs_directory"
  echo "Will create a shell script to start all the executables (from directory_with_executables) in a tmux session (named after the tmuxfile) and log the output to logs_directory"
  echo "both tmuxfile and logs_directory must not exist, the script will create them, not overwrite them"
  exit 1;
}

error_exit() { echo "$1"; exit 1; }
check_file_exists() { if [ ! -f "$1" ]; then error_exit "File $1 does not exist or is not a file"; fi; }
check_file_r() { check_file_exists "$1"; if [ ! -r $1 ]; then error_exit "File $1 is not readable"; fi; }
check_file_w() { check_file_exists "$1"; if [ ! -w $1 ]; then error_exit "File $1 is not writable"; fi; }
check_file_x() { check_file_exists "$1"; if [ ! -x $1 ]; then error_exit "File $1 is not writable"; fi; }

check_dir_exists() { if [ ! -d "$1" ]; then error_exit "Directory $1 does not exist or is not a directory"; fi; }
check_dir_r() { check_dir_exists "$1"; if [ ! -r $1 ]; then error_exit "Directory $1 is not readable"; fi; }
check_dir_w() { check_dir_exists "$1"; if [ ! -w $1 ]; then error_exit "Directory $1 is not writable"; fi; }
check_dir_x() { check_dir_exists "$1"; if [ ! -x $1 ]; then error_exit "Directory $1 is not writable"; fi; }

make_dir() { if [ ! -d "$1" ]; then mkdir -p $1; fi; check_dir_w "$1"; }

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# find the tmux and script commands in path
tmux=$(which tmux)
if [ -z $tmux ]; then error_exit "tmux not found in path"; fi
check_file_x $tmux
script=$(which script)
if [ -z $script ]; then error_exit "script not found in path"; fi

# determine host OS
unameOut="$(uname -s)"
if [ "$unameOut" == "Linux" ]; then
    hostos="Linux"
elif [ "$unameOut" == "Darwin" ]; then
    error_exit "MacOS not supported"
elif [ "$unameOut" == "CYGWIN" ]; then
    error_exit "Cygwin not supported"
elif [ "$unameOut" == "MINGW" ]; then
    error_exit "MinGW not supported"
else
    error_exit "Unknown host OS"
fi

# check variables
if [ -z $1 ]; then usage; fi
if [ -z $2 ]; then usage; fi
if [ -z $3 ]; then usage; fi

tmuxfile=$1
execdir=$2
logsdir=$3

# create an empty tmuxfile
if [ -e "$tmuxfile" ]; then error_exit "tmuxfile ($tmuxfile) already exists, not overwriting"; fi
touch "$tmuxfile"
check_file_w "$tmuxfile"
chmod +x "$tmuxfile"
check_file_x "$tmuxfile"

# create an empty logsdir
if [ -e $logsdir ]; then error_exit "logsdir ($logsdir) already exists, not overwriting"; fi
make_dir "$logsdir"
check_dir_w "$logsdir"

echo "[**] Confirming executable files list from $execdir"
# check that the execdir exists and is readable
check_dir_r "$execdir"
# Get list of executables from within execdir
execdir_ls=$(ls "$execdir")
# check that the executables are executable
execdir_executable=()
for execdir_file in $execdir_ls; do
    if [ -f "$execdir/$execdir_file" ]; then
        if [ -x "$execdir/$execdir_file" ]; then
            check_file_x $execdir/$execdir_file # extra precaution
            echo "  [OK] $execdir_file"
            execdir_executable+=($execdir_file)
        else
            echo "  [--] $execdir_file is not a file/executable, skipping"
        fi
    fi
done

# check that we have at least one executable
if [ ${#execdir_executable[@]} -eq 0 ]; then error_exit "No executable files found in $execdir"; fi

# https://how-to.dev/how-to-create-tmux-session-with-a-script
echo "[**] Writing output file: $tmuxfile"
bn=$(basename $tmuxfile)
# cleanup special characters from the basename to use as the tmux session id
session=$(echo $bn | sed -e 's/[^a-zA-Z0-9]/_/g')

window=0

cat <<EOF > $tmuxfile
#!/bin/bash

$tmux new-session -d -s $session 'echo "tmux started, this window will close in 10 seconds"; sleep 10'
EOF

for f in ${execdir_executable[*]}; do
    ((window++))

    n=`basename $f`
    name=$(echo $n | sed -e 's/[^a-zA-Z0-9]/_/g')
    n="${window}-${name}"

cat <<EOF >> $tmuxfile
$tmux new-window -t $session:$windows -n '$n' '$script -e -O "$logsdir/$n.log" -c "$execdir/$f"'
EOF

    echo "  [++] Added $f"

done

cat <<EOF >> $tmuxfile
$tmux attach-session -t $session
EOF

check_file_x $tmuxfile

echo "Done"
