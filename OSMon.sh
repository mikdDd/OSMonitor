#!/bin/bash

getRcTrBytes()
{
  line=$(tail -1 /proc/net/dev)
  echo $(tail -1 /proc/net/dev | tr -s ' '|cut -d' ' -f2)','$(tail -1 /proc/net/dev |tr -s ' '| cut -d' ' -f10)
}

velocity() {
  newVel=$1
  oldVel=$2
  vel=$(echo $newVel-$oldVel |bc)
  velKB=$(echo $vel/1000 |bc)
  velMB=$(echo $vel/1000000 |bc)
  if [ $velKB != 0 ];
    then
    if [ $velMB != 0 ];
      then echo $velMB MB/s
      else echo $velKB KB/s
    fi
    else echo $vel B/s
  fi
}

recBytesSum()
{
  local -n currSum=$1
  velWithUnit=$2
  itr=$3
  unit=$(echo $velWithUnit|cut -d' ' -f2)
  vel=$(echo $velWithUnit|cut -d' ' -f1)

  if [ $unit == 'B/s' ]; 
    then currSum=$((currSum + vel))
    else if [ $unit == 'KB/s' ]; 
           then currSum=$((currSum + (1000*vel)))
           else currSum=$((currSum + (1000000*vel)))
         fi
  fi  
  avgValue=$(echo $currSum/$itr|bc)
  echo -n $(byteSpeedToUnit $avgValue)
}

drawChart() {
  values=$1' '$2' '$3' '$4' '$5' '$6' '$7' '$8' '$9' '${10}' '${11}' '${12}' '${13}' '${14}' '${15} 
  maxValue=$(echo $values |tr ' ' '\n'|sort -n -r|head -1)

  echo -en "MAX: $(byteSpeedToUnit $maxValue)  _"
  echo -en "\033[10B\033[1D|"

  for i in $values
    do
 
    if [ $maxValue = 0 ]; then height=0
      else  height=$(echo $i*10/$maxValue|bc)
    fi
   
    if [ $height = 0 ]; then echo -en "\033[1C"
     else  
     for ((k=1;k <= $height;k++ ))
     do 
       echo -en "\u2588\033[1A\033[1D"   
     done
   
     echo -en "\033[$(echo $height)B\033[1C"
    fi
    done
  echo -n '|   '
}

speedToBytes() {
  speed=$1
  unit=$2

  if [ "$unit" = "MB/s" ]; then echo $speed*1000000|bc
    else if [ "$unit" = "KB/s" ]; then echo $speed*1000|bc
           else echo $speed
         fi 
  fi
}

byteSpeedToUnit() {
  speedB=$1
  speedKB=$(echo $speedB/1000 |bc)
  speedMB=$(echo $speedB/1000000 |bc)

  if [ $speedKB != '0' ];
  then
    if [ $speedMB != 0 ];
      then echo -n $speedMB MB/s
      else echo -n $speedKB KB/s
    fi
  else echo -n $speedB B/s
  fi
}

battery() {
  full=$(cat /sys/class/power_supply/BAT0/uevent|grep '_FULL='|cut -d'=' -f2)
  current=$(cat /sys/class/power_supply/BAT0/uevent|grep 'ENERGY_NOW='|cut -d'=' -f2)
  echo $(echo $current*100/$full|bc)'%'
}

memoryUsage() {
  freeMem=$(echo $(cat /proc/meminfo |grep 'MemFree'|cut -d' ' -f2-)|cut -d' ' -f1)
  totalMem=$(echo $(cat /proc/meminfo |grep 'MemTotal'|cut -d' ' -f2-)|cut -d' ' -f1)
  cacheMem=$(echo $(cat /proc/meminfo |grep 'Cached'|cut -d' ' -f2-)|cut -d' ' -f1)
  bufferMem=$(echo $(cat /proc/meminfo |grep 'Buffers'|cut -d' ' -f2-)|cut -d' ' -f1)
  usedMem=$(echo $totalMem - $freeMem - $bufferMem - $cacheMem |bc)

  echo $(echo $usedMem*100/$totalMem |bc)'%'
}

 sumOfRec=0
 sumOfTra=0
 iterator=0
 oRecVel=$(echo $(getRcTrBytes) |cut -d',' -f1)
 oTraVel=$(echo $(getRcTrBytes) |cut -d',' -f2)
 valuesToChart='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0'
 valuesToUploadChart='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0'
 
while [ true ]
do 
  clear
  nRecVel=$(echo $(getRcTrBytes) |cut -d',' -f1)
  nTraVel=$(echo $(getRcTrBytes) |cut -d',' -f2)
  downloadSpeed=$(velocity $nRecVel $oRecVel)
  uploadSpeed=$(velocity $nTraVel $oTraVel)

  iterator=$((iterator + 1))

  echo -n 'Download Speed: '$downloadSpeed 'Upload Speed': $uploadSpeed 'AVG Download Speed: '; recBytesSum "sumOfRec" "$downloadSpeed" "$iterator"; echo -n ' AVG upload speed: '; recBytesSum "sumOfTra" "$uploadSpeed" "$iterator"; 
  echo ''  

  valuesToChart=$(echo $valuesToChart|cut -d' ' -f2-)
  valuesToChart=$(echo $valuesToChart $(speedToBytes $downloadSpeed))
  valuesToUploadChart=$(echo $valuesToUploadChart|cut -d' ' -f2-)
  valuesToUploadChart=$(echo $valuesToUploadChart $(speedToBytes $uploadSpeed))

  echo ''
  echo 'Download Speed Chart:'
  drawChart $(echo $valuesToChart)
  echo -en "      \033[11AUpload Speed Chart:\033[1B\033[19D"
  drawChart $(echo $valuesToUploadChart)
  echo ''
  echo ''
  echo 'CPU CORES USAGE: '
  
  oRecVel=$nRecVel
  oTraVel=$nTraVel

  cpuCount=$(cat /proc/stat |sed -n -e '/^cpu[0-9]/p' |wc -l)
  for ((k=1;k <= $cpuCount;k++ ))
   do 
     cpuNow=($(sed -n $(($k+1))'p' /proc/stat))    
     cpuSum=${cpuNow[@]:1}
     cpuSum=$((${cpuSum// /+}))
     cpuDelta=$((cpuSum-cpuLastSum[$k]))
     cpuLtmp=$(echo ${cpuLast[$k]}|cut -d' ' -f5)
     cpuIdle=$((cpuNow[4] - cpuLtmp))
     cpuUsed=$((cpuDelta - cpuIdle))
     cpuUsage=$((100*cpuUsed/cpuDelta))   
     
     cpuLast[$k]=${cpuNow[@]}
     cpuLastSum[$k]=$cpuSum
     coreFreq=$(cat /proc/cpuinfo |sed -n -e '/^cpu MHz/p'|sed -n $k'p'|cut -d':' -f2|cut -d'.' -f1)
     echo "$cpuNow usage: $cpuUsage% $coreFreq MHz"
   done

  uptimeSeconds=$(cat /proc/uptime |cut -d' ' -f1)
  eval "echo -e '\033[1BUPTIME:' $(date -ud "@$uptimeSeconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')"

  echo -e 'BATTERY LEVEL: '$(battery)'\033[1B'
  
  loadAvg=$(cat /proc/loadavg)
  echo -n 'LOAD AVERAGE   IN LAST 1MIN: '$(echo $loadAvg |cut -d' ' -f1)
  echo -n ' IN LAST 5MIN: '$(echo $loadAvg |cut -d' ' -f2)
  echo ' IN LAST 15MIN: '$(echo $loadAvg |cut -d' ' -f3)   
  echo ''

  echo -n 'MEMORY USAGE: '
  memoryUsage

  sleep 1
done


