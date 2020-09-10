#!/bin/bash

#set value of reached
reached=""

logit(){
  #msg=$(echo -e "${FUNCNAME[1]}\t\t:  $1")
  msg=$(printf  '%-20s : %s' "${FUNCNAME[1]}" "$1")
  tm=$(date +"%Y%m%d_%H:%M:%S")
  echo "$tm     :      $msg"
}

statusCheck (){
  val=$1
  func=$2
  if [[ $val -ne 0 ]]; then
    logit "Status check failed on $func"
    logit "Exiting script"
    exit 2
  fi
}

powerDownVm () {
  vm=$1
  logit "Shutting down $vm"
  VBoxManage controlvm $vm poweroff
  statusCheck $(echo $?) ${FUNCNAME}
}

statusCheckVMs (){
  running=$(VBoxManage list runningvms)
  if [[ -z $running ]]; then
    echo 0
  else
    echo 1
  fi
}

pingTest (){
  ip=$1
  reached=$2
  reachable=$(ping -c 1 -t 5 $ip)
  if [[ $reachable =~ "100.0% packet loss" ]]; then
    logit "IP $ip is still not reachable."
    reached="no"
  else
    logit "IP $ip is reachable!"
    reached="yes"
  fi
}

checkIPsValue (){
    instance=$1
    echo $(VBoxManage guestproperty enumerate $instance|grep "Net/0/V4/IP"|grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
}

restartVM (){
  vm=$1
  powerDownVm $vm
  powerUpVm $vm
}

getIPs (){
  vmname=$1
  logit "Waiting for VM $vmname to come fully up. This may take a while."
  rhelInitialIP="$(checkIPsValue $vmname)"
  rhelAfterIP="$(checkIPsValue $vmname)"
  while [ $rhelInitialIP == $rhelAfterIP ]; do
      rhelAfterIP="$(checkIPsValue $vmname)"
      sleep 2
  done
  logit "The ip for $vmname is $rhelAfterIP"
  logit "Doing ping test."
  pingTest $rhelAfterIP
}

powerUpVm (){
  vm=$1
  logit "Starting up vm $vm"
  VBoxManage startvm $vm --type headless
  getIPs $vm
  statusCheck $(echo $?) ${FUNCNAME}
}

checkIfVMsRunning (){
  vm=$1
  pingTest $(checkIPsValue $vm) $reached
  if [[ $reached =~ "yes" ]]; then
        logit "Nothing to do, IP of $vm is reachable"
  else
        logit "IPs of VM $vm is NOT reachable, restarting it now "
        restartVM $vm
  fi
}

#########
# main
#########
anyrunning=$(statusCheckVMs)
reached="no"
if [[ $anyrunning -gt 0 ]]; then
    logit "Some VMs may be running. Checking to see if they are reachable"
    checkIfVMsRunning vv_rhel01
    checkIfVMsRunning vv_rhel02
else
    logit "No VMs running. Starting rhel VMs"
    powerUpVm vv_rhel01
    powerUpVm vv_rhel02
fi

#getIPs vv_rhel01
#getIPs vv_rhel02
