#!/bin/bash
#
# ec2wrap.sh
# Author: sergalma@gmail.com
# Date: 11/06/2012
#
####################################
# set -x 
####################################

usage(){
cat<<EOF
usage: $(basename $0) [OPTIONS] cmd
      -h,--help      			Show this menu.
      --alias				Set alias for an instance.
      -a,--arch      			Architecture (x86,i386..).
      -A,--ami             	        Bootstrap selected AMI.
      -g,--group			Security group (default).
      -k,--keypair			Keypair.
      -n,--multiple-instances		Clone n times the same configuration.
      -r,--region			Region for the instance.
      -t,--instance-type		Instace type.
      -i,--id				Instance ID.
      clone				Clone instance using tags.
      create				Creates a new instance.
      list				Lists instances.
      start				Starts an instance.
      stop				Stops an instance.
      kill 				Terminates an instance.
      tags				List aliases for instances.
EOF
exit
}

# Global configuration variables
EC2_DIR="$HOME/.ec2w"
EC2DIN="$EC2_DIR/ec2din"
EC2_ALIASES="$EC2_DIR/ec2alias"
ID_INSTANCE=""

# Create default configuration
if [ ! -d "$EC2_DIR" ];then
	mkdir "$EC2_DIR" && touch "$EC2_ALIASES" && touch "$EC2_TIMESTAMP"
fi

# Color definition
lred=$(tput bold)$(tput setaf 1)
lgreen=$(tput bold)$(tput setaf 2)
yellow=$(tput bold)$(tput setaf 3)
purpple=$(tput bold)$(tput setaf 5)
lblue=$(tput bold)$(tput setaf 4)
white=$(tput bold)$(tput setaf 7)
red=$(tput bold)$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 4)
reset=$(tput bold)$(tput sgr0)

## Updates the the file on EC2_DIN
update_instances_info() {

	printf "${lgreen}"
	for ((i=0; i < 20; i++))
	do
	        printf "."
		        sleep 3 
		done
	printf "[OK]\n$reset"
	ec2out=$(ec2din |grep -Ei "INSTANCE" > "$EC2DIN" ) 
}

## List the state of the instances and some information, not in realtime. 
## If you either stop or start an instance it will run 'update_instances_info'
## to wait sometime (in the meantime the instance is in pending state)

list_instances() {

	ec2out=$(cat $EC2DIN)
	ninstances=$( echo "$ec2out"  | grep -Ec "INSTANCE" )
	local default="noalias"	

	# Fill in an array with the instances' information, on INSTANCE line
	# one member of the array.
	local -A instances=(  );

	printf "${lblue}AMI\t\t DNS\t\t\t\t\t\t\t STATE\t\t ID\t\t ALIAS${reset}\n"
	for ((n=0; n < $ninstances; n++))
	do
	       	field=$(($n+1))
	        instances["$n"]=$(echo $ec2out   | sed -e 's/INSTANCE //' | awk -F"INSTANCE" "{print $"$field"}")
	       	ami=$(echo     ${instances[$n]}  | grep -Eoi "\bami\-[0-9a-z]*\b") 
		pubdns=$(echo  ${instances[$n]}  | grep -Eoi "ec2.*\.com\>") 
		id=$(echo     ${instances[$n]}   | grep -Eoi "\bi\-[0-9a-z]+\b" )
		state=$( echo  ${instances[$n]}  | grep -Eoi "(running|stopped|pending|terminated)")

		aliasami="$(grep $ami "$EC2_ALIASES" | cut -d':' -f1)"
		aliasami="${aliasami:=$default}"

		
		if [[ "$state" =~ terminated|stopped|pending ]];then 
			printf "$yellow%s$reset\t $white---$reset\t\t\t\t\t\t\t $lred%s$reset\t %s\t %s\t\n" $ami $state $id $aliasami
		else
			printf "$yellow%s$reset\t $white%s\t $lgreen%s$reset\t %s\t %s\n" $ami $pubdns $state $id $aliasami 
		fi

	done
	
}

# Creates the instance with the provided arguments, at least 5 args are required
# AMI, group, keypair, instance type, zone  and optional --alias, which adds
# a tag to a instance so you clone instances using that tag.

create_instance() {

	local -a opts=( $@ )
	alias_instance=${opts[5]}

	# If there is an alias for the instance, unset, otherwise it will not 
	# match the number of the parameters required on the next if case.
	# Add aliases on a file, keeping uniquiness of the aliases.

	if [ -n "$alias_instance" ];then
		unset opts[${#opts[@]}-1]
	fi

	if [ ${#opts[@]} -ne 5 ];then
		printf "Error: args missing, provided %d\n" ${#opts[@]}
		exit 0;
	fi
	
	ins=$(ec2run ${opts[0]} -g ${opts[1]} -k ${opts[2]} -t ${opts[3]} --availability-zone ${opts[4]} --instance-initiated-shutdown-behavior stop)

	# When cloning an ID is requried, in order to update  
	# the '$HOME/.ssh/config'.
	ID_INSTANCE=$( echo  $ins | grep -Eoi "\bi\-[0-9a-z]+\b" )
	if [ -n "$alias_instance" ]; then echo "ALIAS:$alias_instance" ; fi

}

# Starts the instance:
# ec2wrap start -id i-718ae639
start_instance() {

	fn="${funcname%_*}"
	local instance_id="$1"
	printf "Starting $instance_id "
	ins=$(ec2start $instance_id)
	update_instances_info  
	update_ssh_config "$instance_id" "$fn"
}

# Stops the instance:
# ec2wrap stop -id i-718ae639
stop_instance() {

	local id_instance="$1"
	printf "Stopping $id_instance "
	ins=$(ec2stop $id_instance)
	update_instances_info 
}

# Terminates the instane
# ec2wrap kill -id i-718ae639
kill_instance() {

	local id_instance="$1"
	local fn="${FUNCNAME%_*}"

	printf "Do you want to continue?\nPress yes or not:" $id_instance
	read -r -s killornot
        case "$killornot" in
		Y*|y*)
			printf "\n${red}Terminating instance\n"
			ins=$(ec2kill $id_instance)
			update_ssh_config "$id_instance" "$fn"
			;;
		N*|n*)
			printf "\nKilling instance aborted\n"
			exit 0
			;;

		*)	printf "\nAborting\n"
			exit 1
			;;
	esac
	update_instances_info 
}

update_ssh_config() {

	local instance_id="$1"	
	local action="$2"

	new_public_dns=""
		
	if [ "$action" != "kill" ];then
	       	while [ "$new_public_dns" == "" ]
	       	do
		       	new_public_dns=$( ec2din | grep $instance_id | grep -Eoi "ec2.*\.com\>")
	       	done 
	fi

	# Check if there is  already an entry,
        # delete 'Hostname' entry just after the match of 'Host' 
	# and then insert the new one.

	cmd=$(grep -Eqi "$instance_id" $HOME/.ssh/config )

	if [ "$action" == "kill" ];then
		set -x
		printf "${lgreen}Updating .ssh/config$reset"
		if [ -n "$instance_id" ];then
		       	r=$(sed -i "/Host $instance_id/,+3d" $HOME/.ssh/config)
		fi
		exit 0
	else 
		# If there is not match, add a new entry for that AMI.  
		if [ $? -ne 0 ]; then
cat<< EOF >> $HOME/.ssh/config

Host $instance_id
	Hostname $new_public_dns
       	User root
       	IdentityFile /home/$USER/.ssh/ec2-centos.pem	
EOF
		else 
			r=$(sed -i  "/Host $instance_id/,+1 s/\(Hostname\) \(.*\)/\1 $new_public_dns/" $HOME/.ssh/config )
			if [ $? -eq 0 ];then
				printf "Updated for %s successful \n" $new_public_dns
			fi
		fi
	fi
}

# List all aliases or a given one
tags() {

	# List a given alias or list all if the file exists
	# and is not empty.
	local alias="$1"
	if [ -s "$EC2_ALIASES" ];then
		if [ -n "$alias" ];then
			match=$(grep -Ei "$alias" $EC2_ALIASES)
			printf "%s\n" $match
			exit 0;
		fi
		cat "$EC2_ALIASES" 
	fi
}

# Clone instances using alias
# ec2wrap clone --alias=memache 
# NOTE: allow to change options from an alias
clone() {

	local fn="$FUNCNAME"
	local ec2_aliases_file="$EC2_ALIASES" 
	local -a options=( $2 )
	local alias="$1"
	
	printf "${lblue}Cloning $alias $reset"
	if [ -s "$ec2_aliases_file" -a  -n "$alias" ];then
		grep -Eiq "\b$alias:"  "$ec2_aliases_file"
		if [ $? -ne 0 ];then
			printf "Error: alias (%s) not found\n"  $alias
			exit 1
		else
			# Get all the parameters, allow to override some
			# and call create_instance with this array.
	
			ami=$(     grep -Ei "$alias" "$ec2_aliases_file" |awk 'BEGIN{FS=":"}{print $2}' )
			group=$(   grep -Ei "$alias" "$ec2_aliases_file" |awk 'BEGIN{FS=":"}{print $3}' )
			keypair=$( grep -Ei "$alias" "$ec2_aliases_file" |awk 'BEGIN{FS=":"}{print $4}' )
			typeins=$( grep -Ei "$alias" "$ec2_aliases_file" |awk 'BEGIN{FS=":"}{print $5}' )
			zone=$(    grep -Ei "$alias" "$ec2_aliases_file" |awk 'BEGIN{FS=":"}{print $6}' )

			clone_instance=( $ami $group $keypair $typeins $zone )

			if [ "$_DEBUG"  == "1" ];then
				echo "AMI: $ami"
				echo "Group: $group"
				echo "Keypair: $keypair"
				echo "Type: $typeins"
				echo "Zone: $zone"
			fi

			create_instance "${clone_instance[@]}"	
		fi
	else
		printf "Error: alias not found or file not defined\n"
	fi	
	update_instances_info
	update_ssh_config "$ID_INSTANCE" "$fn"
	printf "$lred ssh $ID_INSTANCE\n" 
	checkKey=$(ssh -o StrictHostKeyChecking=no $ID_INSTANCE)
}

## Main 

[ "$#" -gt 0 ] || usage

set -- `getopt -u  -n$0 -o ha:A:g:i:k:t:n:r: -l help,arch:,ami:,group:,id:,key-pair:,instance-type:,multiple-instances:,zone:,alias:: -- "$@"`

default_instances="1"
while [ $# -gt 0 ]
do
    case "$1" in
       -a|--arch) architecture=$2;shift;;
       -A|--ami) ami=$2;shift;;
       -g|--group) group=$2;shift;;
       -i|--id) id=$2;shift;;
       -k|--key-pair) keypair=$2;shift;;
       -n|--multiple-instances) ninstances=$2;shift;;
       -r|--zone) zone=$2;shift;;
       -t|--instance-type) instance_type=$2;shift ;;
       --alias) aka=$2;shift ;;
       -h|--help)      usage;;
       --)	;;
       *)         break;;            
    esac
    shift
done

declare -a options_new_instance=( $ami $group $keypair $instance_type $zone $aka) 

option="$1"
case ${option} in
	create)		create_instance "${options_new_instance[@]}" ;;
	clone)		clone "$aka" "${options_new_instance[@]}" ;;
	list)   	list_instances ;;
	start)	        if [ -n "$id" ]; then start_instance "$id"; fi
			;;
	stop) 		if [ -n "$id" ]; then stop_instance "$id"; fi
			;;
	kill)     	kill_instance "$id" ;;
	tags)       	printf "[Tags]\n";tags "$aka";;
	update)       	printf "Manual update " 
			update_instances_info
		;;
	*) echo "Not found";;
esac

