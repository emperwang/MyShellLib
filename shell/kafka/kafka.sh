#!/bin/bash
# chkconfig:2345 80 90
# description start service
Path=/opt/kafka_2.11
KafkaPath=${Path}/bin/kafka-server-start.sh
KafkaConfig=${Path}/config/server.properties

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

startKafka(){
 executeCMD  "nohup ${KafkaPath} -daemon ${KafkaConfig} >/dev/null 2>&1 &"
}

stopKafka(){
    pid=($(ps -ef | grep -Ev 'grep|root' | grep 'kafka' | awk '{print $2}'))
    if [ "${#pid[@]}" -le 0 ];then
        echo "no kafka running"
        exit 0
    else
        for pp in ${pid[@]}
        do
            echo "stopping $pp"
            kill $pp
        done

    fi
}

statusKafka(){
    vv=($(ps -ef | grep -Ev 'grep|root' | grep 'kafka' | awk '{print $2}'))
    echo "kafka $vv running"
}

main(){

    if [ $# -ne 1 ]; then
        echo "usage: $0 [start | stop | restart | status]"
        exit 0
    fi
    case $1 in
    start)
        startKafka
    ;;
    stop)
        stopKafka
    ;;
    restart)
        stopKafka
        sleep 2
        startKafka
    ;;
    status)
        statusKafka
    ;;
    *)
        echo "usage: $0 [start | stop | restart | status]"
    ;;
    esac
}

main $1