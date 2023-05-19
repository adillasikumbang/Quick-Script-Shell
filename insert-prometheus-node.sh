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
    PS3='Enter the number of the type of instance you want to add: '
    options=("node_exporter" "cadvisor" "Custom" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "node_exporter")
                instance_type="node_exporter"
                break
                ;;
            "cadvisor")
                instance_type="cadvisor"
                break
                ;;
            "Custom")
                read -p "Enter the type of instance you want to add: " instance_type
                instance_type="${instance_type}_exporter"
                break
                ;;
            "Quit")
                exit 0
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    read -p "Enter the instance name: " instance_name
    # Remove "_exporter" from the instance name
    job_name="${instance_type%_exporter}_$instance_name"

    while true; do
        read -p "Enter the instance IP: " instance_ip
        if valid_ip $instance_ip; then break; else echo "Invalid IP, please retry"; fi
    done

    read -p "Enter the instance port: " instance_port

    temp_file=$(mktemp)

    cat <<EOF > $temp_file
  - job_name: '$job_name'
    scrape_interval: 5s
    static_configs:
      - targets: ['$instance_ip:$instance_port']
EOF

    # Check if the instance type exists in the prometheus.yml file
    if grep -q "#### ${instance_type} ####" prometheus.yml; then
        # If it does, append the new instance configuration at that position
        sed -i "/#### ${instance_type} ####/r $temp_file" prometheus.yml
    else
        # If it doesn't, append the new instance configuration at the end of the file
        echo "#### ${instance_type} ####" >> prometheus.yml
        cat $temp_file >> prometheus.yml
    fi

    rm $temp_file

    read -p "Do you want to add another instance? (y/n): " answer
    if [[ $answer != "y" ]]; then
        break
    fi
done
