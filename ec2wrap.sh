#!/bin/bash
#====================================================================
#
# title:	ec2wrap.sh
# description:  Manage EC2 instances in a easy way from the shell
# author:	sergalma@gmail.com
# date:		11-06-2012
# version:	0.1
# dependencies: Java JRE and Amazon EC2 tools
# special:	Setting '_DEBUG=1' as a shell env var, allows to debug
#               without running commands.
#
#=====================================================================
# set -x  : Comment out if you want to start debugging
#=====================================================================

usage(){
cat<<EOF
usage: $(basename $0) [OPTIONS] cmd
      -h,--help      			Show this menu.
      -a,--alias			Set alias for an instance.
      -g,--group			Security group (default).
      -k,--keypair			Keypair.
      -m,--ami             	        Bootstrap selected AMI.
      -n,--multiple-instances		Clone 'n' times the same configuration.
      -z,--zone				Availability zone for the instance.
      -t,--instance-type		Instace type.
      -i,--id				Instance ID.
      aliases				List aliases for instances.      
      clone				Clone instance using tags.
      create				Create a new instance.
      kill 				Terminate an instance.
      list				List instances.
      start				Start an instance.
      stop				Stop an instance.
      update                            Run manual update.
      
EOF
exit
}

# Global configuration variables
EC2_DIR="$HOME/.ec2w"
EC2DIN="$EC2_DIR/ec2din"
EC2_ALIASES="$EC2_DIR/ec2alias"
ID_INSTANCE=""

# Creates a default configuration
if [ ! -d "$EC2_DIR" ];then
	mkdir "$EC2_DIR" && touch "$EC2_ALIASES" 
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

# Updates the file on EC2_DIN
update_instances_info() {

	printf "${lgreen}"
	for ((i=0; i < 20; i++)); do
	        printf "."
	        sleep 3 
	done
	printf "[OK]\n$reset"
	ec2out=$(ec2din |grep -Ei "INSTANCE" > "$EC2DIN" ) 
}

## List the state of the instances and some information else, not in realtime. 
## If you either stop or start an instance it will run 'update_instances_info'.
list_instances() {

	if [ ! -e "$EC2DIN" ];then
		ec2out=$(ec2din |grep -Ei "INSTANCE" > "$EC2DIN" ) 
	fi

	ec2out=$(cat $EC2DIN)
	ninstances=$( echo "$ec2out"  | grep -Ec "INSTANCE" )
	local default="undefine"	

	# Fill in an array with the instances' information, one INSTANCE line
	# is one element of the array.
	local -A instances=(  );

	printf "${lblue}AMI\t\t DNS\t\t\t\t\t\t\t STATE\t\t ID\t\t ALIAS\t\t INS.TYPE${reset}\n"
	for ((n=0; n < $ninstances; n++))
	do
	       	field=$(($n+1))
	        instances["$n"]=$(echo $ec2out   | sed -e 's/INSTANCE //' | awk -F"INSTANCE" "{print $"$field"}")
	       	ami=$(echo     ${instances[$n]}  | grep -Eoi "\bami\-[0-9a-z]*\b") 
		pubdns=$(echo  ${instances[$n]}  | grep -Eoi "ec2.*\.com\>") 
		id=$(echo     ${instances[$n]}   | grep -Eoi "\bi\-[0-9a-z]+\b" )
		state=$( echo  ${instances[$n]}  | grep -Eoi "(running|stopped|pending|terminated)")
		instyp=$(echo  ${instances[$n]}  | grep -Eoi "[t|m|c|g]{1,2}[0-9]\.[0-9]?[a-z]+" )

		aliasami="$(grep $id "$EC2_ALIASES" | cut -d':' -f1)"
		aliasami="${aliasami:=$default}"

		if [[ "$state" =~ terminated|stopped|pending ]];then 
			printf "$yellow%s$reset\t $white---$reset\t\t\t\t\t\t\t $lred%s$reset\t %s\t %s\t %s\n" $ami $state $id $aliasami $instyp
		else
			printf "$yellow%s$reset\t $white%s\t $lgreen%s$reset\t %s\t %s\t %s\n" $ami $pubdns $state $id $aliasami $instyp
		fi
	done
}

# Creates the instance with the provided arguments, at least 5 args are required
# AMI, group, keypair, instance type, zone  and optionally '--alias', which associates
# an alias to an instance, so you can clone instances using that alias.
create_instance() {
	local -a opts=( $@ )
	local fn="${FUNCNAME%_*}"
	local keypair="${opts[2]}"
	alias_instance=${opts[5]}
	
	if [ -n "$alias_instance" ];then
	    unset opts[${#opts[@]}-1]
	fi

	if [ ${#opts[@]} -ne 5 ];then
	    printf "Error: args missing, provided %d\n" ${#opts[@]}
	    exit 0;
	fi
	
       	# Shutdown behavior only valid for EBS instances. I only tinker with
	# EBS instances, so I'm aware I harcoded this behaviour, although it should be changed.
	ins=$(ec2run ${opts[0]} -g ${opts[1]} -k ${opts[2]} -t ${opts[3]} -z ${opts[4]} --instance-initiated-shutdown-behavior stop)

	# When cloning, an ID is requried, in order to update  
	# the '$HOME/.ssh/config'.

	ID_INSTANCE=$( echo  $ins | grep -Eoi "\bi\-[0-9a-z]+\b" )

	# If there is an alias for the instance, unset, otherwise it will not 
	# match the number of the parameters required on the next if case.
	# Add aliases on a file, keeping uniquiness of the aliases. 

	if [ -n "$alias_instance" ];then
		# Add new alias to the EC2_ALIASES file.
	    printf "%s"  $alias_instance >> $EC2_ALIASES
	    printf ":%s" ${opts[@]} >> $EC2_ALIASES
	    printf ":%s\n" $ID_INSTANCE >> $EC2_ALIASES
	fi
	if [ -n "$alias_instance" ]; then printf "Alias set to  ${lgreen}$alias_instance${reset}\n" ; fi
	set +x	
	# Add the entry to ssh config.
	update_ssh_config "$ID_INSTANCE" "$fn" "$keypair"

}

# Starts the instance:
# ec2wrap start -id i-718ae639
start_instance() {

	local fn="${FUNCNAME%_*}"
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

# Terminates the instance
# ec2wrap kill -id i-718ae639
kill_instance() {

	local id_instance="$1"
	local fn="${FUNCNAME%_*}"

	printf "Do you want to continue? Press yes or not:" $id_instance
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

# Updates '$HOME/.ssh/config' with a new entry, if there is not 
# previous instance ID or updates the public dns of that instance.
update_ssh_config() {
	
	local instance_id="$1"	
	local action="$2"
	local keypair="$3"
	local new_public_dns=""
		
	if [ "$action" != "kill" ];then
	       	while [ "$new_public_dns" == "" ]
	       	do
		       	new_public_dns=$( ec2din | grep $instance_id | grep -Eoi "ec2.*\.com\>")
	       	done 
	fi

	# Check if there is already an entry,
        # delete 'Hostname' entry just after the match of 'Host' 
	# and then insert the new one.

	if [ "$action" == "kill" ];then
		printf "${lgreen}Updating .ssh/config$reset"
		if [ -n "$instance_id" ];then
		       	r=$(sed -i "/Host $instance_id/,+3d" $HOME/.ssh/config)
		fi
	else 
		cmd=$(grep -Eqi "$instance_id" $HOME/.ssh/config )

		# If there is not match, add a new entry for that AMI.  
		if [ $? -ne 0 ]; then
cat<< EOF >> $HOME/.ssh/config

Host $instance_id
	Hostname $new_public_dns
       	User root
       	IdentityFile /home/$USER/.ssh/${keypair}.pem	
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
aliases() {

	# List a given alias or list all if the file exists
	# and is not empty.
	local alias="$1"
	if [ -s "$EC2_ALIASES" ];then
		if [ "$alias" != "--" ];then
			match=$(grep -Ei "$alias" $EC2_ALIASES)
			printf "${white}%s${reset}\n" $match
			exit 0;
		fi
		cat "$EC2_ALIASES" 
	fi
}

# Clone instances using alias
# ec2wrap clone --alias=memcache 
clone() {

	local fn="$FUNCNAME"
	local ec2_aliases_file="$EC2_ALIASES" 
	eval "declare -A override="${1#*=}
	alias="${override['aka']}"
	
 	if [ -z "${override['aka']}" ];then
		printf "Error: an alias must be provided\n"
		exit 1
	fi

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
			
			# Allow to overrided some of the options and create a new instance.

			if [ -n "${override['group']}" ];then
				group=${override['group']}
			fi

			if [ -n "${override['keypair']}" ];then
				keypair=${override['keypair']}
			fi
if [ -n "${override['instance_type']}" ];then
				typeins=${override['instance_type']}
			fi
			
			if [ -n "${override['zone']}" ];then
				zone=${override['zone']}
			fi
			
			clone_instance=( $ami $group $keypair $typeins $zone )

			if [ "$_DEBUG"  == "1" ];then
				echo  "AMI: $ami"
				echo "Group: $group"
				echo "Keypair: $keypair"
				echo "Type: $typeins"
				echo "Zone: $zone"
			fi
			
			if [ "$_DEBUG" == "" ];then
			    for((  j=0;  j < ${override['ninstances']} ; j++));do 
				printf "${lblue}Cloning $alias $reset" 
				create_instance "${clone_instance[@]}"
				update_instances_info
			    done
			fi
		fi
	else
		printf "Error: alias not found or file not defined\n"
	fi	
}

# Parameter substitution shows what variable failed, 
# otherwise runs smoothly.
check_environment() {
       	${EC2_HOME:?}        2>/dev/null
	${EC2_KEYPAIR:?}     2>/dev/null
	${EC2_PRIVATE_KEY:?} 2>/dev/null
       	${EC2_CERT:?} 	     2>/dev/null
       	${EC2_URL:?}	     2>/dev/null
       	${EC2_HOME:?}        2>/dev/null
       	${JAVA_HOME:?}       2>/dev/null
}
## Main 

check_environment
[ "$#" -gt 0 ] || usage

set -- `getopt -u  -n$0 -o hg::m:i:k:t:n::z:a:: -l help,group::,ami:,id:,keypair:,instance_type:,multiple-instances:,zone::,alias:: -- "$@"`

default_group="default"
default_instances=1
while [ $# -gt 0 ]
do
    case "$1" in
       -a|--alias) aka=$2;shift;;
       -g|--group) group=$2;shift;;
       -i|--id) id=$2;shift;;
       -k|--keypair) keypair=$2;shift;;
       -m|--ami) ami=$2;shift;;
       -n|--multiple-instances) ninstances=$2;shift;;
       -t|--instance-type) instance_type=$2;shift ;;
       -z|--zone) zone=$2;shift;;
       -h|--help) usage;;
       --)	;;

       *)         break;;            
    esac
    shift
done

group=${group:=$default_group}
ninstances=${ninstances:=$default_instances}

declare -a options_new_instance=( $ami $group $keypair $instance_type $zone $aka) 
declare -A override=( ['group']=$group ['keypair']=$keypair ['instance_type']=$instance_type  ['zone']=$zone ['aka']=$aka ['ninstances']=$ninstances);

option="$1"
case ${option} in
    create)	create_instance "${options_new_instance[@]}"; update_instances_info ;;
    clone)	clone  "$(declare -p override)";;
    list)   	list_instances ;;
    start)	if [ -n "$id" ]; then start_instance "$id"; fi	;;
    stop) 	if [ -n "$id" ]; then stop_instance "$id"; fi;;
    kill)     	kill_instance "$id" ;;
    aliases)       	printf "$lred[${reset}${green}Aliases${red}]$reset\n";aliases "$aka";;
    update)       	printf "Manual update " && update_instances_info ;;
    *) echo "Not found";;
esac

