#!/bin/bash

function valid_ip()
{
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

while true; do
    read -p "Enter the instance name: " instance_name
    instance_name="node_$instance_name"

    while true; do
        read -p "Enter the instance IP: " instance_ip
        if valid_ip $instance_ip; then break; else echo "Invalid IP, please retry"; fi
    done

    read -p "Enter the instance port: " instance_port

    temp_file=$(mktemp)

    cat <<EOF > $temp_file
  - job_name: '$instance_name'
    scrape_interval: 5s
    static_configs:
      - targets: ['$instance_ip:$instance_port']
EOF

    sed -i '/#### node_exporter ####/r '$temp_file prometheus.yml
    rm $temp_file

    read -p "Do you want to add another instance? (y/n): " answer
    if [[ $answer != "y" ]]; then
        break
    fi
done
