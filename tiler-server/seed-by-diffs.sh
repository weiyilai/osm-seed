#!/bin/bash
set -a
set +a

workDir=/mnt/data

expire_dir=$workDir/imposm/imposm3_expire_dir
mkdir -p $expire_dir

# this will be essentially treated as a pidfile
queued_jobs=$workDir/imposm/in_progress.list
# output of seeded
completed_jobs=$workDir/imposm/completed.list

# a directory to place the worked expiry lists
# THIS MUST BE OUTSIDE OF $expire_dir
completed_dir=$workDir/imposm/imposm3_expire_purged
mkdir -p $completed_dir

# assert no other jobs are running
# if [[ -f $queued_jobs ]]; then
#   exit
# else
#   touch $queued_jobs
#   if [[ ! $? ]]; then
#     rm $queued_jobs
#     exit
#   fi
# fi


# files newer than this amount of seconds will
# not be used for this job

# list Files in dir
imp_list=`find $expire_dir -type f`

for f in $imp_list; do
    echo "$f" >> $queued_jobs
done

# Sort the files and set unique rows
sort -u $queued_jobs > $workDir/imposm/tmp.list && mv $workDir/imposm/tmp.list $queued_jobs

for f in $imp_list; do
    echo "seeding from $f"
    # Read each line of the tiles file
    while IFS= read -r tile
    do
        bounds="$(python tile2bounds.py $tile)"
        echo tegola cache purge \
        --config=/opt/tegola_config/config.toml \
        --min-zoom=0 --max-zoom=20 \
        --bounds=$bounds \
        tile-name=$tile
        
        tegola cache purge \
        --config=/opt/tegola_config/config.toml \
        --min-zoom=0 --max-zoom=20 \
        --bounds=$bounds \
        tile-name=$tile
        err=$?
        if [[ $err != "0" ]]; then
            #error
            echo "tegola exited with error code $err"
            # rm $queued_jobs
            exit
        fi
    done < "$f"
    echo "$f" >> $completed_jobs
    mv $f $completed_dir
done

echo "finished seeding"
rm $queued_jobs