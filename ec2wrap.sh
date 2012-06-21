#!/bin/bash
#
# Author: sergalma@gmail.com
# Date: 11/06/2012
#
####################################

usage(){
cat<<EOF
usage: $(basename $0) [OPTIONS] cmd
      -h,--help      			Show this menu
      -a,--arch      			Architecture (x86,i386..)
      -A,--ami             	        Bootstrap selected AMI
      -g,--group			Security group (default)
      -k,--keypair			Keypair
      -n,--multiple-instances		Clone n times the same configuration
      -r,--region			Region for the instance
      -t,--instance-type		Instace type 
      create				Creates a new instance
      list				Lists instances
      start				Starts an instance
      stop				Stops an instance
      terminate				Terminates an instance
EOF
exit
}

EC2_CONF="$HOME/.ec2w"

# Create default configuration
if [ ! -d "$EC2_CONF" ];then
	mkdir "$EC2_CONF" && touch "$EC2_CONF/ec2alias"
fi

# Color debug
red='$(tput setaf 1)'
green='$(tput setaf 2)'
yellow='$(tput setaf 3)'
blue='$(tput setaf 4)'
reset='$(tput sgr0)'


list_instances() {
	echo "Listing..."
	ec2out=$(ec2din | grep -Ei "Instance" )
	ami=$(echo $ec2out        | grep -Eoi "\bami\-[0-9a-z]*\b")
	public_dns=$(echo $ec2out | grep -Eoi "ec2-[0-9]{2,3}.*\.com\>")

	printf "AMI: %s\t   Public-DNS: %s\n" $ami $public_dns
}

create_instance() {
	local -a options=( $@ )

	if [ ${#options[@]} -ne 5 ];then
		printf "Error: args missing, provided %d\n" ${#options[@]}
		exit 0;
	fi

	create_ins=$(ec2run ${options[0]} -g ${options[1]} -k ${options[2]} -t ${options[3]} --availability-zone ${options[4]} --instance-initiated-shutdown-behavior stop )

}

start_instance() {

	#new_public_dns=$(ec2din | grep -Eoi "ec2.*\.com\>")
	#sed -ie "s/ec2.*\.com/$new_public_dns/" .ssh/config
	echo "Nothing"
}

[ "$#" -gt 0 ] || usage


set -- `getopt -u  -n$0 -o ha:A:g:k:t:n:r: -l help,arch:,ami:,group:,key-pair:,instance-type:,multiple-instances:,region: -- "$@"`

default_instances="1"
while [ $# -gt 0 ]
do
    case "$1" in
       -a|--arch) architecture=$2;shift;;
       -A|--ami) ami=$2;shift;;
       -g|--group) group=$2;shift;;
       -k|--key-pair) keypair=$2;shift;;
       -n|--multiple-instances) ninstances=$2;shift;;
       -r|--region) region=$2;shift;;
       -t|--instance-type) instance_type=$2;shift ;;
       -h|--help)      usage;;
       --)	;;
       *)         break;;            
    esac
    shift
done

declare -a options_new_instance=( $ami $group $keypair $instance_type $region ) 

if [ "$_DEBUG" == "1" ];then
	# Give color
	echo -e "$r**DEBUGGING**$reset:Options new instance: ${#options_new_instance[@]} \n ${options_new_instance[@]}\n"
fi

option="$1"
case ${option} in
	create)		create_instance "${options_new_instance[@]}" ;;
	list)   	list_instances ;;
	start)	        echo "Start";;
	stop) 		echo "Stop" ;;
	terminate)      echo "Terminate";;
	*) echo "Not found";;
esac
