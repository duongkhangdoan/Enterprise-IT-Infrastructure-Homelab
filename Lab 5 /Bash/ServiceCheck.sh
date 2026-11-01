#!/bin/bash
# Lab 5 - Ubuntu service monitoring and logging

services=("ssh" "apache2" "smbd")
logfile="$HOME/ServiceCheck.log"

for service in "${services[@]}"; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if systemctl is-active --quiet "$service"; then
        echo -e "\e[32m$service : RUNNING\e[0m"
        echo "$timestamp $service : RUNNING" >> "$logfile"
    else
        echo -e "\e[31m$service : NOT RUNNING\e[0m"
        echo "$timestamp $service : NOT RUNNING" >> "$logfile"
    fi
done
