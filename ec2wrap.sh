#!/bin/bash
#
# Author: sergalma@gmail.com
# Date: 11/06/2012
#
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
      terminate				Terminates an instance.
      tags				List aliases for instances.
EOF
exit
}

# Global configuration variables
EC2_DIR="$HOME/.ec2w"
EC2DIN="$EC2_DIR/ec2din"
EC2_ALIASES="ec2alias"
EC2_TIMESTAMP="$EC2_DIR/timestamp"

# Create default configuration
if [ ! -d "$EC2_DIR" ];then
	mkdir "$EC2_DIR" && touch "$EC2_DIR/$EC2_ALIASES" && touch "$EC2_TIMESTAMP"

fi

# Color debug
red='$(tput setaf 1)'
green='$(tput setaf 2)'
yellow='$(tput setaf 3)'
blue='$(tput setaf 4)'
reset='$(tput sgr0)'

update_instances_info() {
	printf "Updating instances"
	for ((i=0; i < 40; i++))
	do
	        printf "."
		        sleep 1
		done
	printf "\n"
	ec2out=$(ec2din |grep -Ei "INSTANCE" > "$EC2DIN" ) 
}

list_instances() {

	echo "Listing..."
	ec2out=$(cat "$EC2DIN")

	local  ninstances=$( echo "$ec2out" | grep -ic "INSTANCE" )
	local -a ami=( $(echo $ec2out       | grep -Eoi "\bami\-[0-9a-z]*\b") );
	local -a public_dns=( $(echo $ec2out| grep -Eoi "ec2\-([0-9]{1,3}\-){3}[0-9]{1,3}.eu-west-1.compute.amazonaws.com") );
	local -a ids=(      $( echo $ec2out | grep -Eoi "\bi\-[0-9a-z]+\b" ) );
	local -a state=(    $( echo $ec2out | grep -Eoi "(running|stopped)") );
	local default="noalias"	

	for index in `seq 0 $(($ninstances -1))` 
	do
		aliasami="$(grep ${ami[$index]} "$EC2_DIR/$EC2_ALIASES" | cut -d':' -f1)"
		aliasami="${aliasami:=$default}"
		#printf "AMI: %s\t Pub-DNS: %s (%s)  ID: %s\t Alias:%s\n" ${ami[$index]} ${public_dns[$index]} ${state[$index]} ${ids[$index]} $aliasami 
		if [ "${state[$index]}" == "stopped" ];then
			printf "AMI: %s\t ID: %s\t [%s]\n" ${ami[$index]} ${ids[$index]} ${state[$index]}
		else

			printf "AMI: %s\t Pub-DNS: %s (%s)  ID: %s\t Alias:%s\n" ${ami[$index]} ${public_dns[$index]} ${state[$index]} ${ids[$index]} $aliasami 
		fi
	done
}

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
	if [ -n "$alias_instance" ]; then echo "ALIAS:$alias_instance" ; fi

}

start_instance() {

	local id_instance="$1"
	echo "Starting $id_instance"
	ins=$(ec2start $id_instance)
	update_instances_info 

	#new_public_dns=$(ec2din | grep -Eoi "ec2.*\.com\>")
	#sed -ie "s/ec2.*\.com/$new_public_dns/" .ssh/config
}

stop_instance() {

	local id_instance="$1"
	echo "Stopping $id_instance"
	ins=$(ec2stop $id_instance)
	update_instances_info 
}


tags() {

	# List a given alias or list all if the file exists
	# and is not empty.

	local alias="$1"
	if [ -s "$EC2_DIR/$EC2_ALIASES" ];then
		if [ -n "$alias" ];then
			match=$(grep -Ei "$alias" $EC2_DIR/$EC2_ALIASES)
			printf "%s\n" $match
			exit 0;
		fi
		cat "$EC2_DIR/$EC2_ALIASES" 
	fi
	
}

clone() {

	local ec2_aliases_file="$EC2_DIR/$EC2_ALIASES" 
	local -a options=( $2 )
	local alias="$1"

	if [ -s "$ec2_aliases_file" -a  -n "$alias" ];then
		grep -Eiq "\b$alias:"  "$ec2_aliases_file"
		if [ $? -ne 0 ];then
			printf "Error: alias (%s) not found\n"  $alias
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
}

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

if [ "$_DEBUG" == "1" ];then
	# Give color
	echo -e "$r**DEBUGGING**$reset:Options new instance: ${#options_new_instance[@]} \n ${options_new_instance[@]}\n"
fi

option="$1"
case ${option} in
	create)		create_instance "${options_new_instance[@]}" ;;
	clone)		clone "$aka" "${options_new_instance[@]}" ;;
	list)   	list_instances ;;
	start)	        if [ -n "$id" ]; then start_instance "$id"; fi
			;;
	stop) 		if [ -n "$id" ]; then stop_instance "$id"; fi
			;;
	terminate)      echo "Terminate";;
	tags)       	echo "[Tags]";tags "$aka";;
	*) echo "Not found";;
esac

