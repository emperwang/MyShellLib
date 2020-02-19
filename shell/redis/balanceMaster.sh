#!/bin/bash
BASE=$(cd $(dirname $0);pwd)
ClientPath=/root/redis-cluster/9001
Client=${ClientPath}/redis-cli
Ip=$(cat ${ClientPath}/redis.conf | grep -v '^#' | grep bind | awk '{print $2}')
Port=9001

# 此脚本是监控redis集群的，集群是三主三从
# 如过实例数量不是6个  那么就不执行
# 任务: 监测当前集器上的9001端口的实例是否是master，如果不是则进行一次晋升，晋升没有成功，则输出1

checkCount(){
    ct=$($Client --cluster check ${Ip}:${Port} | grep -E 'M|S' | wc -l)
    if [ "$ct" -ne 6 ];then
        exit 1
    fi  
}

promote(){
        $(${Client} -h $Ip -p $Port cluster failover force) > /dev/null 2>&1
        sleep 2
}

checkMaster(){
    checkCount
    flag=$(${Client} --cluster check ${Ip}:${Port} | grep -E 'M|S' | grep '192.168.30.10:9001' | awk -F: '{print $1}')
    if [ "${flag}" == 'M' ];then
        echo "0"
        exit 
    else 
        return 1
    fi  
}
main(){
    checkMaster
    if [ "$?" -eq 1 ];then
        promote
    fi  
    checkMaster
    if [ "$?" -eq 1 ]; then
        echo "1"
    fi
}

main