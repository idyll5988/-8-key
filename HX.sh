#!/system/bin/sh
[ ! "$MODDIR" ] && MODDIR=${0%/*}
MODPATH="/data/adb/modules/key"
date="$( date "+%y年%m月%d日%H时%M分%S秒")"
[[ ! -e ${MODDIR}/ll/log ]] && mkdir -p ${MODDIR}/ll/log
function log() {
    logfile="1000000"
    maxsize="1000000"
    if [ "$(stat -c %s "${MODDIR}/ll/log/哈希值.log")" -eq "$maxsize" ] || [ "$(stat -c %s "${MODDIR}/ll/log/哈希值.log")" -gt "$maxsize" ]; then
        rm -f "${MODDIR}/ll/log/哈希值.log"
    fi
}
cd "${MODDIR}/ll/log"
logcat > "${MODDIR}/ll/log/VBMeta_Digest.txt" &
vbmeta_digest=""
attempts=("bootlog" "getprop" "logcat" "resetprop" "direct" "fastboot" "cmdline")
for attempt in "${attempts[@]}"; do
    log
    case $attempt in
        "bootlog")        
            vbmeta_digest=$(grep "VBMeta Digest:" "${MODDIR}/ll/log/bootlog.txt" | sed -n 's/.*VBMeta Digest:[[:space:]]*$$[^[:space:]]*$$.*/\1/p')
            ;;
        "getprop")
            vbmeta_digest=$(getprop ro.boot.vbmeta.digest 2>/dev/null)
            ;;
        "logcat")
		    logcat -d | grep "VBMeta Digest:" | awk '{print $3}' > "${MODDIR}/ll/log/VBMeta_Digest.txt"
            vbmeta_digest=$(cat "${MODDIR}/ll/log/VBMeta_Digest.txt")
            ;;
        "resetprop")
            vbmeta_digest=$(resetprop -n ro.boot.vbmeta.digest 2>/dev/null)
            ;;
        "direct")
            if [ -r "/sys/block/bootloader/by-name/vbmeta/digest/sha256" ]; then
                vbmeta_digest=$(cat /sys/block/bootloader/by-name/vbmeta/digest/sha256)
            fi
            ;;
		"fastboot")
            vbmeta_digest=$(fastboot oem get vbmeta_digest 2>/dev/null)
            ;;
        "cmdline")
            vbmeta_digest=$(cat /proc/cmdline | sed 's/ /\n/g' | grep "androidboot.vbmeta.digest" | awk -F '=' '{print $2}') 
            ;;			
    esac
    if [ -n "$vbmeta_digest" ]; then
        echo "${date}*已找到哈希值：$vbmeta_digest*" >> 哈希值.log
		su -c setprop ro.boot.vbmeta.digest "$vbmeta_digest"
		resetprop ro.boot.vbmeta.digest "$vbmeta_digest"
        break
	else
       echo "${date}*尝试：$attempts获取VBMeta哈希值失败*" >> 哈希值.log
    fi
    sleep 1
done
pkill -f logcat
rm -f "${MODDIR}/ll/log/VBMeta_Digest.txt"
if [ -n "$vbmeta_digest" ]; then
    echo "${date}*成功设置新值哈希值*" >> 哈希值.log
else
    echo "${date}*设置新值哈希值失败*" >> 哈希值.log
fi

