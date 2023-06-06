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

function check_duplicate_ip_and_type()
{
    local type=$1
    local ip=$2
    local port=$3
    grep -q "$ip:$port" prometheus.yml && grep -B 2 "$ip:$port" prometheus.yml | grep -q "$type"
    return $?
}

function check_duplicate_name()
{
    local name=$1
    grep -q "job_name: '$name'" prometheus.yml
    return $?
}

function print_duplicate_instance()
{
    local name=$1
    grep -A 4 "job_name: '$name'" prometheus.yml
}

instance_summary=""

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
                echo -e "\nSummary of Instances:"
                echo -e "$instance_summary"
                curl -X POST http://localhost:8430/-/reload
                exit 0
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done

    while true; do
        read -p "Enter the instance name: " instance_name
        job_name="${instance_type%_exporter}_$instance_name"
        if check_duplicate_name $job_name; then 
            echo "Duplicate instance name, please retry"
            echo -e "\nDuplicate Instance Summary:"
            print_duplicate_instance $job_name
        else 
            break
        fi
    done

    while true; do
        read -p "Enter the instance IP: " instance_ip
        if valid_ip $instance_ip; then break; else echo "Invalid IP, please retry"; fi
    done

    while true; do
        read -p "Enter the instance port: " instance_port
        if check_duplicate_ip_and_type $instance_type $instance_ip $instance_port; then 
            echo "Same IP address with different instance type found, please retry"
        else 
            break
        fi
    done

    temp_file=$(mktemp)

    cat <<EOF > $temp_file
  - job_name: '$job_name'
    scrape_interval: 5s
    static_configs:
      - targets: ['$instance_ip:$instance_port']

EOF

    echo -e "#### ${instance_type} ####\n" >> prometheus.yml
    cat $temp_file >> prometheus.yml
    instance_summary+="Instance Type: $instance_type\nInstance Name: $instance_name\nInstance IP: $instance_ip\nInstance Port: $instance_port\n\n"

    rm $temp_file

    read -p "Do you want to add another instance? (y/n): " answer
    if [[ $answer != "y" ]]; then
        echo -e "\nSummary of Instances:"
        echo -e "$instance_summary"
        curl -X POST http://localhost:8430/-/reload
        break
    fi
done
