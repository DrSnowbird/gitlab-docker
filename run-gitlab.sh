#!/bin/bash

MY_DIR=$(dirname "$(readlink -f "$0")")
if [ $# -lt 1 ]; then
    echo "Usage: "
    echo "  ${0} <container_shell_command>"
    echo "e.g.: "
    echo "  ${0} ls -al "
fi

###################################################
#### ---- Change this only to use your own ----
###################################################
ORGANIZATION=openkbs
baseDataFolder="$HOME/data-docker"
GITLAB_HOME="$HOME/data-docker"
PORT_GITLAB=28022
PORT_WEB_HTTP=28080
PORT_GIT_HTTPS=28443

###################################################
#### **** Container package information ****
###################################################
MY_IP=`ip route get 1|awk '{print$NF;exit;}'`
DOCKER_IMAGE_REPO=`echo $(basename $PWD)|tr '[:upper:]' '[:lower:]'|tr "/: " "_" `
imageTag="${ORGANIZATION}/${DOCKER_IMAGE_REPO}"
#PACKAGE=`echo ${imageTag##*/}|tr "/\-: " "_"`
PACKAGE="${imageTag##*/}"

###################################################
#### ---- (DEPRECATED but still supported)    -----
#### ---- Volumes to be mapped (change this!) -----
###################################################
# (examples)
# IDEA_PRODUCT_NAME="IdeaIC2017"
# IDEA_PRODUCT_VERSION="3"
# IDEA_INSTALL_DIR="${IDEA_PRODUCT_NAME}.${IDEA_PRODUCT_VERSION}"
# IDEA_CONFIG_DIR=".${IDEA_PRODUCT_NAME}.${IDEA_PRODUCT_VERSION}"
# IDEA_PROJECT_DIR="IdeaProjects"
# VOLUMES_LIST="${IDEA_CONFIG_DIR} ${IDEA_PROJECT_DIR}"

# ---------------------------
# Variable: VOLUMES_LIST
# (NEW: use .env with "#VOLUMES_LIST=data workspace" to define entries)
# ---------------------------
## -- If you defined locally here, 
##    then the definitions of volumes map in ".env" will be ignored.
# VOLUMES_LIST="data workspace"

# ---------------------------
# OPTIONAL Variable: PORT PAIR
# (NEW: use .env with "#PORTS=18000:8000 17200:7200" to define entries)
# ---------------------------
## -- If you defined locally here, 
##    then the definitions of ports map in ".env" will be ignored.
#### Input: PORT - list of PORT to be mapped
# (examples)
#PORTS_LIST="18000:8000"
#PORTS_LIST=

#########################################################################################################
######################## DON'T CHANGE LINES STARTING BELOW (unless you need to) #########################
#########################################################################################################
LOCAL_VOLUME_DIR="${baseDataFolder}/${PACKAGE}"
## -- Container's internal Volume base DIR
DOCKER_VOLUME_DIR="/home/developer"

###################################################
#### ---- Function: Generate volume mappings  ----
####      (Don't change!)
###################################################
VOLUME_MAP=""

#### Input: VOLUMES - list of volumes to be mapped
hasPattern=0
function hasPattern() {
    detect=`echo $1|grep "$2"`
    if [ "${detect}" != "" ]; then
        hasPattern=1
    else
        hasPattern=0
    fi
}

function generateVolumeMapping() {
    if [ "$VOLUMES_LIST" == "" ]; then
        ## -- If locally defined in this file, then respect that first.
        ## -- Otherwise, go lookup the .env as ride-along source for volume definitions
        VOLUMES_LIST=`cat .env|grep "^#VOLUMES_LIST= *"|sed "s/[#\"]//g"|cut -d'=' -f2-`
    fi
    for vol in $VOLUMES_LIST; do
        echo "$vol"
        hasColon=`echo $vol|grep ":"`
        ## -- allowing change local volume directories --
        if [ "$hasColon" != "" ]; then
            left=`echo $vol|cut -d':' -f1`
            right=`echo $vol|cut -d':' -f2`
            leftHasDot=`echo $left|grep "\./"`
            if [ "$leftHasDot" != "" ]; then
                ## has "./data" on the left
                if [[ ${right} == "/"* ]]; then
                    ## -- pattern like: "./data:/containerPath/data"
                    echo "-- pattern like ./data:/data --"
                    VOLUME_MAP="${VOLUME_MAP} -v `pwd`/${left}:${right}"
                else
                    ## -- pattern like: "./data:data"
                    echo "-- pattern like ./data:data --"
                    VOLUME_MAP="${VOLUME_MAP} -v `pwd`/${left}:${DOCKER_VOLUME_DIR}/${right}"
                fi
                mkdir -p `pwd`/${left}
                ls -al `pwd`/${left}
            else
                ## No "./data" on the left
                if [[ ${right} == "/"* ]]; then
                    ## -- pattern like: "data:/containerPath/data"
                    echo "-- pattern like ./data:/data --"
                    VOLUME_MAP="${VOLUME_MAP} -v ${LOCAL_VOLUME_DIR}/${left}:${right}"
                else
                    ## -- pattern like: "data:data"
                    echo "-- pattern like data:data --"
                    VOLUME_MAP="${VOLUME_MAP} -v ${LOCAL_VOLUME_DIR}/${left}:${DOCKER_VOLUME_DIR}/${right}"
                fi
                mkdir -p ${LOCAL_VOLUME_DIR}/${left}
                ls -al ${LOCAL_VOLUME_DIR}/${left}
            fi
        else
            ## -- pattern like: "data"
            echo "-- default sub-directory (without prefix absolute path) --"
            VOLUME_MAP="${VOLUME_MAP} -v ${LOCAL_VOLUME_DIR}/$vol:${DOCKER_VOLUME_DIR}/$vol"
            mkdir -p ${LOCAL_VOLUME_DIR}/$vol
            ls -al ${LOCAL_VOLUME_DIR}/$vol
        fi
    done
}

#### ---- Generate Volumes Mapping ----
generateVolumeMapping
echo ${VOLUME_MAP}

###################################################
#### ---- Function: Generate port mappings  ----
####      (Don't change!)
###################################################
PORT_MAP=""
function generatePortMapping() {
    if [ "$PORTS" == "" ]; then
        ## -- If locally defined in this file, then respect that first.
        ## -- Otherwise, go lookup the .env as ride-along source for volume definitions
        PORTS_LIST=`cat .env|grep "^#PORTS_LIST= *"|sed "s/[#\"]//g"|cut -d'=' -f2-`
    fi
    for pp in ${PORTS_LIST}; do
        #echo "$pp"
        port_pair=`echo $pp |  tr -d ' ' `
        if [ ! "$port_pair" == "" ]; then
            # -p ${local_dockerPort1}:${dockerPort1} 
            host_port=`echo $port_pair | tr -d ' ' | cut -d':' -f1`
            docker_port=`echo $port_pair | tr -d ' ' | cut -d':' -f2`
            PORT_MAP="${PORT_MAP} -p ${host_port}:${docker_port}"
        fi
    done
}

#### ---- Generate Port Mapping ----
generatePortMapping
echo ${PORT_MAP}

###################################################
#### ---- Function: Generate privilege String  ----
####      (Don't change!)
###################################################
privilegedString=""
function generatePrivilegedString() {
    OS_VER=`which yum`
    if [ "$OS_VER" == "" ]; then
        # Ubuntu
        echo "Ubuntu ... not SE-Lunix ... no privileged needed"
    else
        # CentOS/RHEL
        privilegedString="--privileged"
    fi
}
generatePrivilegedString
echo ${privilegedString}

###################################################
#### ---- Mostly, you don't need change below ----
###################################################
function cleanup() {
    if [ ! "`docker ps -a|grep ${instanceName}`" == "" ]; then
         docker rm -f ${instanceName}
    fi
}

function displayURL() {
    port=${1}
    echo "... Go to: http://${MY_IP}:${port}"
    #firefox http://${MY_IP}:${port} &
    if [ "`which google-chrome`" != "" ]; then
        /usr/bin/google-chrome http://${MY_IP}:${port} &
    else
        firefox http://${MY_IP}:${port} &
    fi
}

###################################################
#### ---- Replace "Key=Value" withe new value ----
###################################################
function replaceKeyValue() {
    inFile=${1:-./.env}
    keyLike=$2
    newValue=$3
    if [ "$2" == "" ]; then
        echo "**** ERROR: Empty Key value! Abort!"
        exit 1
    fi
    sed -i -E 's/^('$keyLike'[[:blank:]]*=[[:blank:]]*).*/\1'$newValue'/' $inFile
}

#### ---- Replace .env with local user's UID and GID ----
#replaceKeyValue ./.env "USER_ID" "$(id -u $USER)"
#replaceKeyValue ./.env "GROUP_ID" "$(id -g $USER)"

## -- transform '-' and space to '_' 
#instanceName=`echo $(basename ${imageTag})|tr '[:upper:]' '[:lower:]'|tr "/\-: " "_"`
instanceName=`echo $(basename ${imageTag})|tr '[:upper:]' '[:lower:]'|tr "/: " "_"`

echo "---------------------------------------------"
echo "---- Starting a Container for ${imageTag}"
echo "---------------------------------------------"

if [ ! "${privilegedString}" == "" ]; then
    privilegedString=":Z"
fi
  
#GITLAB_HOME="$HOME/data-docker"
#PORT_GITLAB=28022
#PORT_WEB_HTTP=28080
#PORT_GIT_HTTPS=28443
# ref: https://stackoverflow.com/questions/60062065/gitlab-initial-root-password

sudo docker run -it \ # --detach \
    --hostname gitlab.example.com \
    --publish ${PORT_GIT_HTTPS}:443 --publish ${PORT_WEB_HTTP}:80 --publish ${PORT_GITLAB}:22 \
    --name gitlab-docker \
    --restart always \
    -e GITLAB_ROOT_EMAIL="root@local" \
    -e GITLAB_ROOT_PASSWORD="gitlab_root_password" \
    --volume $GITLAB_HOME/gitlab/config:/etc/gitlab${privilegedString} \
    --volume $GITLAB_HOME/gitlab/logs:/var/log/gitlab${privilegedString} \
    --volume $GITLAB_HOME/gitlab/data:/var/opt/gitlab${privilegedString} \
    gitlab/gitlab-ce:latest
