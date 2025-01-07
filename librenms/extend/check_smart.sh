#!/bin/bash
# /usr/local/bin/check_smart.sh

for drive in /dev/sd[a-z]; do
    if [ -e "$drive" ]; then
        echo "=== $drive ==="
        /usr/sbin/smartctl -a -d sat,auto -T permissive "$drive"
    fi
done

for nvme in /dev/nvme[0-9]n[0-9]; do
    if [ -e "$nvme" ]; then
        echo "=== $nvme ==="
        /usr/sbin/smartctl -a -T permissive "$nvme"
    fi
done