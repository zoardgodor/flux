function worker
set lockfile $argv[1]
set counterfile $argv[2]
set total_chunks $argv[3]

while true
    set chunk_id (flock "$lockfile" sh -c '
        n=$(cat "$1") || exit 1
        printf "%s\n" "$((n + 1))" > "$1" || exit 1
        printf "%s\n" "$n"
        ' sh "$counterfile")

        if test -z "$chunk_id"; or test "$chunk_id" -gt "$total_chunks"
        break
        end

        echo "Worker $fish_pid received chunk $chunk_id"
        sleep (random 1 3)
    end
end

set testdir (mktemp -d)
set lockfile "$testdir/lock"
set counterfile "$testdir/counter"

touch "$lockfile"
echo 1 > "$counterfile"

set pids

for i in (seq 5)
worker "$lockfile" "$counterfile" 20 &
echo "Started worker PID: $last_pid"
set -a pids $last_pid
end

for pid in $pids
wait $pid
end

echo "Final counter: "(cat "$counterfile")

rm -rf "$testdir"