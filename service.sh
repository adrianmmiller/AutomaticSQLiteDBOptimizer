#!/system/bin/sh
MODDIR=${0%/*}			  

options_file="/storage/emulated/0/autosqlite_options"
log_file="/storage/emulated/0/autosqlite.log"

# delete logfile if older than 7 days
find /storage/emulated/0/ -name "$log_file" -type f -maxdepth 1 -mtime +7d -delete

wait_avg_cpu_usage() {
#wait 60 seconds
sleep 60
# set threshold as first argument passed to function
threshold=$1
while true; do
    # get 5 minute avg and format it as a whole number
    current=$(cat /proc/loadavg | cut -f 2 -d " " | xargs  printf "%.0f")
    echo $current
    if [ $current -lt $threshold ]; then
        break;
    else
        sleep 5
    fi
done
}

function run_footer() {
    echo ' Auto SQLite DB Optimizer: Finished' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    echo ' =============================================' | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    echo -ne '=============================================\n\n' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    # Store the current date as modification time stamp of this script file
    touch -m -- "$0"
}

function no_run_footer() {
    # dont run sqlite3 optimization
    echo ' Auto SQLite DB Optimizer: NOT Needed' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    echo ' =============================================' | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    echo -ne ' =============================================\n\n' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file	
    exit
}

# main function
function optimize () {
for i in $(find /data/* -iname "*.db"); do
    sqlite3 "$i" 'VACUUM;'
    resVac=$?
    if [[ "$resVac" == "0" ]]; then
        resVac="SUCCESS"
    elif [[ "$resVac" != "0" ]]; then
        resVac="FAILED(ERRCODE)-$resVac"
    fi
    sqlite3 "$i" 'REINDEX;'
    resIndex=$?
    if [[ "$resIndex" == "0" ]]; then
        resIndex="SUCCESS"
    elif [[ "$resIndex" != "0" ]]; then
        resIndex="FAILED(ERRCODE)-$resIndex"
    fi
    sqlite3 "$i" 'ANALYZE;'
    resAnlz=$?
    if [[ "$resAnlz" == "0" ]]; then
        resAnlz="SUCCESS"
    elif [[ "$resAnlz" != "0" ]]; then
        resAnlz="FAILED(ERRCODE)-$resAnlz"
    fi
    # When loglevel is set to 1 every databases optmized status is added to log 
    # warning, it can get lengthy of you enable this
    #
    if [ $loglevel -eq 1 ]; then
        echo -ne " Database $i: VACUUM=$resVac REINDEX=$resIndex ANALYZE=$resAnlz\n" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    fi
done
}


# wait till boot completed
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 120
done

# wait until avg cpu usage is less than 30%
wait_avg_cpu_usage 30

# read options from options file if it exists
if [ -f "$options_file" ]; then
    # source options file into script
    . $optionsfile
    # get interval value from interval key
    interval="${interval}"
    # get loglevel value from loglevel key
    loglevel="${loglevel}"
else
    # set default interval
    interval=3
    # set default loglevel	
    loglevel=0
fi

echo ' =============================================' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
echo ' =============================================' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
echo ' Auto SQLite DB Optimizer' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
if [ -f "$options_file" ]; then
    echo ' Options file located ' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
fi	
echo " Script Schedule: every $interval days" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
echo " Log Level: $loglevel" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
echo ' =============================================' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file

# check for required sqlite3 file
echo ' Checking for sqlite3 binary....' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
if [ -f /data/data/com.termux/files/usr/bin/sqlite3 ] ; then
    sqlpath=/data/data/com.termux/files/usr/bin
    echo " sqlite3 binary found in: $sqlpath" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
elif [ -f /data/data/com.keramidas.TitaniumBackup/files/sqlite3 ] ; then
    sqlpath=data/data/com.keramidas.TitaniumBackup/files/sqlite3
    echo " sqlite3 binary found in: $sqlpath" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
elif [ -f /system/bin/sqlite3 ] ; then
    sqlpath=/system/bin
    echo " sqlite3 binary found in: $sqlpath" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
elif [ -f /system/xbin/sqlite3 ] ; then
    sqlpath=/system/xbin
    echo " sqlite3 binary found in: $sqlpath" 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
else 
    echo ' sqlite3 binary not found...' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    echo ''
    exit
fi
echo ' =============================================' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file

# minimum delay between script executions, in seconds, last figure ($interval) is days 
seconds=$((60*60*24*$interval)) 

# First run after install
if [ -f /storage/emulated/0/autosqlite_first_run ]; then
    echo ' Automatic SQLite Optimization: First Run' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    # run sqlite3 optimization
    optimize
    # show footer we use for if optimize has run
    run_footer
    # remove the first run file
    rm -f /storage/emulated/0/autosqlite_first_run
    # Compare the difference between this script's modification time stamp 
    # and the current date with the given minimum delay in seconds. 
    # Exit with error code 1 if the minimum delay is not exceeded yet.
elif test "$(($(date "+%s")-$(date -r "$0" "+%s")))" -lt "$seconds" ; then
    # show footer we use for if optimize has NOT run
    no_run_footer
else	
    echo ' Automatic SQLite Optimization: Started' 2>&1 | ts '[%d/%m/%Y %H:%M:%S]' | tee -a $log_file
    # run sqlite3 optimization
    optimize
    # show footer we use for if optimize has run    
    run_footer
fi

exit
