#!/bin/bash
#
# Name: ec2wrap
#
####################################



usage(){
cat<<EOF
usage: $(basename $0) [OPTIONS] cmd
      -h,--help      			Show this menu
      -p <public-dns>			Instance public-ip*
      -a,--arch      			Architecture (x86,i386..)
      -A,--ami             	        Bootstrap selected AMI
      -R,--region			Region for the instance
      -G,--group			Security group
      -k,--key-pair			Key pair
      -t,--instance-type		Instace type 
      list				List avilable AMIs
      start				Starts an instance
      stop				Stops an instance
      terminate				Terminates an instance

EOF
exit
}

list_instances() {
	echo "Listing..."
}

[ "$#" -lt 1 ] && usage

set -- `getopt  -n$0 -o ha:A:G:k:t:p: -l help,arch:,ami:,group:,key-pair:,instance-type:,public-dns: -- "$@"`

default_instances="1"
while [ $# -gt 0 ]
do
    case "$1" in
       -a|--arch) architecture=$2;shift;;
       -A|--ami) ami=$2;shift;;
       -G|--group) group=$2;shift;;
       -p|--public-dns) public_dns=$2;shift ;;
       -n|--create-multiple-instances) ninstances=$2;shift;;
       -h|--help)      usage;;
       --)        usage;shift;break;;
       -*)        usage;;
       *)         break;;            
    esac
    shift
done

#echo "architecture: $architecture"
#echo "ami: $ami"
#echo "group: $group"
#echo "public-dns: $public_dns"

option="${1:1:${#1}-2}"

case ${option,,} in
	list)   	echo "List" ;;
	start)		 echo "Start";;
	stop) 		echo "Stop" ;;
	terminate)      echo "Terminate";;
	*) echo "Not found";;
esac
