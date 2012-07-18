#!/bin/bash

describe "Wrapper to manage EC2 instances"

it_runs_if_ec2_env_vars_are_present() {

    echo "EC2_HOME        is present ${EC2_HOME+1}"        | grep "1"	
    echo "EC2_KEYPAIR     is present ${EC2_KEYPAIR+1}"     | grep "1"	
    echo "EC2_PRIVATE_KEY is present ${EC2_PRIVATE_KEY+1}" | grep "1"	
    echo "EC2_CERT        is present ${EC2_CERT+1}"        | grep "1"	
    echo "EC2_URL         is present ${EC2_URL+1}" 	   | grep "1"	
    echo "JAVA_HOME       is present ${JAVA_HOME+1}"       | grep "1"	
}

it_should_show_help_without_args() {

	show_help=$(./ec2wrap.sh  | head -1)
	echo $show_help
	test "$show_help" "=" "usage: ec2wrap.sh [OPTIONS] cmd"
}

it_should_list_own_instances() {
	list_own_instances="AMI              DNS                                                     STATE           ID              ALIAS"
	if [ -z $list_own_instances ];then  false; fi
}	

it_should_fail_without_arguments() {
	fail_without_args=$(./ec2wrap.sh create )
	echo "$fail_without_args" | grep -Ei "1" 
}

