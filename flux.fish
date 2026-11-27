#!/usr/bin/fish

if not type -q curl
    read -P "curl is not installed. Do you want to install it now? (only on debian-based systems) [y/n] " curlyn
    if test "$curlyn" = "y"
        if not type -q apt
            echo "Error. Install curl manually"
            exit
        else
            sudo apt update && sudo apt install curl
        end
    else
    echo "Please install curl manually"
    exit
    end
end
if not type -q curl
echo "curl installation failed"
exit
end
if not type -q flock
    read -P "flock is not installed. Do you want to install it now? (only on debian-based systems) [y/n] " flockyn
    if test "$flockyn" = "y"
    if not type -q apt
    echo "Install flock manually for your system"
    exit
    else
    sudo apt update && sudo apt install util-linux
    end
    else
    echo "Please install flock manually"
    exit
    end
end
if not type -q flock
echo "flock installation failed"
exit
end
function install
    if not test -d ~/.local/bin
        mkdir -p ~/.local/bin
    end
    cp (status filename) ~/.local/bin/flux
    chmod +x ~/.local/bin/flux
    echo "Flux installed successfully. You can now run 'flux' from your terminal."
end

function help
    echo "Usage: flux [option] or flux.fish [option]"
    echo "Options:"
    echo "  --install or -i   Install the flux script to ~/.local/bin"
    echo "  --help or -h     Show this help message"
    echo "Run the script without any options to download a file"
end

function worker
    set lockfile $argv[1]
    set counterfile $argv[2]
    set totalchunks $argv[3]
    set chunksize $argv[4]
    set size $argv[5]
    set url $argv[6]
    set tempdir $argv[7]

    while true
    if test -e "$tempdir/cancel"
    return
    end
        set chunkid (flock "$lockfile" sh -c '
            n=$(cat "$1") || exit
            printf "%s\n" "$((n + 1))" > "$1" || exit
            printf "%s\n" "$n"
            ' sh "$counterfile")
            if test -z "$chunkid"
            return
            end
            if test "$chunkid" -gt "$totalchunks"
            break
            end
            set s (math "($chunkid - 1) * $chunksize")
            set e (math "$s + $chunksize -1")
            if test "$e" -ge "$size"
            set e (math "$size -1")
            end

            set chunkfile (printf "%s/chunk_%08d" "$tempdir" "$chunkid")
            set pidfile "$tempdir/worker_$fish_pid.pid"

            curl -fLsS -r "$s-$e" -o "$chunkfile" "$url" &
            set curlpid $last_pid
            echo $curlpid > "$pidfile"
            if test -e "$tempdir/cancel"
            kill -TERM "$curlpid" 2>/dev/null
            end
            wait $curlpid
            set curlstatus $status
            rm -f "$pidfile"
            if test $curlstatus -ne 0
            return
            end
    end
end

function down
    read -P "Enter the URL to a file to download: " url
    read -P "Enter the output folder path (press enter for the default path: ~/): " out
    if test -z "$out"
    set out ~/
    end
    if not test -d "$out"
        read -P "Output folder does not exist. Do you want to create it? [y/n] " cr
        if test "$cr" = "y"
        mkdir -p "$out"
        else
        echo "Exiting..."
        exit
        end
    end
    read -P "How many threads do you want to use for the download? (default: 8) " threads
    if test -z "$threads"
        set threads 8
    end
    set size (curl -sIL "$url" | string match -ri 'content-length: *[0-9]+' | string match -r '[0-9]+')
    if test -z "$size"
     echo "Could not determine file size. Exiting..."
        exit
    end

    set rcode (curl -sSL -r 0-0 -o /dev/null -w '%{http_code}' "$url")
    if test "$rcode" != "206"
    echo "Server does not support Range requests."
    echo "Switching to single-threaded download mode. (Slower download speed)"
    set threads 1
    end

    if test "$rcode" = "206"
    set chunksize (math "8 * 1024 * 1024")
    set total (math --scale=0 "($size + $chunksize - 1) / $chunksize")
    else
    set chunksize $size
    end
    set total (math --scale=0 "($size + $chunksize - 1) / $chunksize")
    set filen (string split "/" "$url" | tail -n 1 | string split "?" | head -n 1)
    if test -z "$filen"
    read -P "Could not determine file name. What is the name of the file? (e.g. ubuntu.iso) " filen
    end
    if test -d "$out/fluxtemp"
        echo "fluxtemp directory already exists in the output folder. If you created this folder, rename it, now, before continuing. Do you want to continue? [y/n] "
        read cont
        if test "$cont" != "y"
            echo "Exiting..."
            exit
        end
    end
    rm -rf "$out/fluxtemp"
    mkdir -p "$out/fluxtemp"
    set pids
    if test -e "$out/$filen"
        read -P "File $filen already exists in the output folder. Do you want to overwrite it? [y/n] " exist
        if test "$exist" = "y"
            rm -f "$out/$filen"
        else
            echo "Exiting..."
            exit
        end
    end
    set lockfile "$out/fluxtemp/lock"
    set counterfile "$out/fluxtemp/counter"
    touch "$lockfile"
    echo 1 > "$counterfile"
    set script_path (status filename)
    set pids

    for bb in (seq $threads)
    fish "$script_path" --worker "$lockfile" "$counterfile" "$total" "$chunksize" "$size" "$url" "$out/fluxtemp" &
    set -a pids $last_pid
    end
    set downloaded 0
    while jobs -q
    set downloaded1 0
    set key (bash -c 'read -r -s -n 1 -t 0.1 key; printf "%s" "$key"')
    if test "$key" = "q"
        echo "Cancelling download..."
        touch "$out/fluxtemp/cancel"
        for pidfile in (find "$out/fluxtemp" -maxdepth 1 -name 'worker_*.pid' -type f)
        set curlpid (cat "$pidfile")
        if string match -q '^[0-9]+$' -- "$curlpid"
            kill -TERM "$curlpid" 2>/dev/null
        end
        end
        for pid in $pids
        wait $pid 2>/dev/null
        end
        rm -rf "$out/fluxtemp"
        echo "Download cancelled."
        exit
    end

        for file in "$out"/fluxtemp/*
        if test -f "$file"
        set fsize (stat -c %s "$file")
        set downloaded1 (math "$downloaded1 + $fsize")
        end
    end
    set percent (math --scale=1 "$downloaded1 * 100 / $size")
    set speed (math --scale=2 "($downloaded1 - $downloaded) / 1048576")
    set filen (string split "/" "$url" | tail -n 1 | string split "?" | head -n 1)
    printf "\rProgress: %.1f%%, Speed: %.2f MB/s (press q to quit)" $percent $speed
    set downloaded $downloaded1
    sleep 1
end
    set fail 0
    for pid in $pids
        wait $pid
        if test $status -ne 0
            set fail 1
        end
    end
    if test $fail -eq 1
        echo "Some downloads failed. Please check your internet connection and try again."
        exit
    end
    echo "All downloads finished!"
    set filen (string split "/" "$url" | tail -n 1 | string split "?" | head -n 1)
    cat "$out"/fluxtemp/* > "$out/$filen"
    rm -rf "$out/fluxtemp"
end

switch $argv[1]
    case "--install" "-i"
        install
    case "-h" "--help"
        help
    case "--worker"
        worker $argv[2] $argv[3] $argv[4] $argv[5] $argv[6] $argv[7] $argv[8]
    case "*"
        down
end