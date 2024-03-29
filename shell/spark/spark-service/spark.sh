#!/bin/bash
#chkconfig:2345 80 90
#description: spark service

ss=$(which bash 2>/dev/null)
run=${ss:=/bin/bash}
Port=8080
ServerPort=7077
Path=/opt/spark-2.4.3
# 从文件中读取时, 要注意去除多余的符号; 最后的sed就是去除 特殊符号
Hosts=($(cat ${Path}/conf/slaves | grep -Ev "^#|^$" | sed 's#\r\|\n\|\r\n##g'))
SMaster=${Path}/sbin/start-master.sh
SSlave=${Path}/sbin/start-slave.sh
PMaster=${Path}/sbin/stop-master.sh
PSlave=${Path}/sbin/stop-slave.sh

## 加上用户判断，不然fcaps用户执行会让输入密码
SUDO_fcaps=""
if [ "$(whoami)" != "fcaps" ]; then
    SUDO_fcaps="su - fcaps -c"
fi

## 当前用户如果不是fcaps，则使用fcaps用户执行命令，如果是fcaps用户，则直接执行命令
executeCMD(){
    if [ "${SUDO_fcaps}" != "" ];then
        ${SUDO_fcaps} "$1" 2>/dev/null
    else
        $1 2>/dev/null
    fi  
}

getMaster(){
    if [ "${#Hosts[@]}"  -le 0 ];then
        echo "HostName must be give"
        exit 1
    fi
    local cc=0
    for hh in ${Hosts[@]}
    do  
        tt=$(curl -X GET http://${hh}:${Port} 2>/dev/null | grep "Status" | grep "ALIVE")
        if [ "$?" -eq 0 ];then
            iph=$(curl -X get http://${hh}:${Port} 2>/dev/null | grep "URL" | awk -F'//' '{print $2}' | awk -F'<' '{print $1}')
            echo $iph
        else
            let cc+=1
        fi  
        if [ "$cc" -ge "${#Hosts[@]}" ];then
            echo "No Master running"
            exit 1
        fi  
    done
}

startMaster(){
    ck=$(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.master.Master' | awk '{print $2}')
    if [ -z "$ck" ];then        
        echo "starting Master..."
        executeCMD "$run  $SMaster >/dev/null 2>&1"
    else                    
        echo "Master $ck is running"
        exit 0
    fi  
}

stopMaster(){
    ck=($(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.master.Master' | awk '{print $2}'))
    if [ "${#ck[@]}" -le 0 ];then   
        echo "No Master running"
        exit 1
    else        
        echo "stopping master  $ck"
        executeCMD "$run $PMaster >/dev/null 2>&1"
    fi
}

restartMaster(){
    stopMaster
    sleep 3
    startMaster
}
startSlave(){
    ck=$(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.worker.Worker' | awk '{print $2}')
    if [ -z "$ck" ];then
        ipm=$(getMaster)
        if [ -n "$ipm" ]; then
            echo "starting slave..."
            executeCMD "$run $SSlave $ipm >/dev/null 2>&1"
        else
            echo "No Master running"
        fi
    else
        echo "Slave $ck is running"
        exit 0
    fi
}

stopSlave(){
    ck=$(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.worker.Worker' | awk '{print $2}')
    if [ -n "$ck" ]; then
        echo "stopping slave  $ck"
        executeCMD "$run $PSlave >/dev/null 2>&1"
    else
        echo "No Slave Running"
        exit 1
    fi
}

restartSlave(){
    stopSlave
    sleep 3
    startSlave
}

startAll(){
    startMaster
    sleep 3
    startSlave
}

stopAll(){
    stopSlave
    stopMaster
}

restartAll(){
    restartMaster
    restartSlave
}
statusAll(){
    ck=$(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.worker.Worker' | awk '{print $2}')
    ck1=($(ps -ef | grep -v grep |  grep 'org.apache.spark.deploy.master.Master' | awk '{print $2}'))
    if [ -n "$ck" ]; then
        echo "Slave $ck Running"
    fi

    if [ -n "$ck1" ]; then
        echo "Master $ck1 Running"
    fi
}
main(){
    if [ "$#" -ne 1 ];then
        echo "usage:$0 [start| stop |restart | status | startMaster | stopMaster | restartMaster | startSlave | stopSlave | restartSlave]"
        exit 0
    fi
    case $1 in
    start)
        startAll
    ;;
    stop)
        stopAll
        ;;
    restart)
        restartAll
        ;;
    status)
        statusAll
        ;;
    startMaster)
        startMaster
        ;;
    stopMaster)
        stopMaster
        ;;
    restartMaster)
        restartMaster
        ;;
    startSlave)
        startSlave
        ;;
    stopSlave)
        stopSlave
        ;;
    restartSlave)
        restartSlave
        ;;
    *)
        echo "usage:$0 [start| stop |restart | status | startMaster | stopMaster | restartMaster | startSlave | stopSlave | restartSlave]"
         ;;
    esac
}

main $1