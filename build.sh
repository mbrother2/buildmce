#!/bin/bash
# Auto Install LAMP or LEMP on CentOS 6,7
# Version: 1.0
# Author: mbrother

# Set variables
SCRIPT_NAME=$0
ALL_OPTIONS="$@"
OS_VER=`rpm -E %centos`
OS_ARCH=`uname -m`
IPADDRESS=`ip route get 1 | awk '{print $NF;exit}'`
DIR=`pwd`
BASH_DIR="/var/mce/script"
GITHUB_LINK="https://raw.githubusercontent.com/mbrother2/buildmce/master"
LOG_FILE="/var/mce/log/install.log"
DEFAULT_DIR_WEB="/var/www/html"
REMI_DIR="/etc/opt/remi"
LSWS_DIR="/usr/local/lsws"
VHOST_DIR="/etc/nginx/conf.d"

# List support versions
List_PHP=(all 5.4 5.5 5.6 7.0 7.1 7.2 7.3 7.4)
List_SQL=(5.5 10.0 10.1 10.2 10.3 10.4)
List_NODEJS=(8.x 9.x 10.x 11.x 12.x 14.x)
List_FTP=(proftpd pure-ftpd)
List_WEB=(nginx openlitespeed)
List_EXTRA=(all phpmyadmin letsencrypt memcached redis vnstat)
List_SECURITY=(all csf imunify clamav)
List_STACK=(lemp lomp)

# Default services & version
PMD_VERSION_MAX="5.0.2"
PMD_VERSION_COMMON="4.9.5"
DEFAULT_FTP_SERVER="pure-ftpd"
DEFAULT_PHP_VERSION="7.4"
DEFAULT_SQL_SERVER="10.4"
DEFAULT_WEB_SERVER="nginx"
DEFAULT_NODEJS="12.x"
DEFAULT_VNSTAT_VERSION="2.6"

# Control panel
CPANEL="/usr/local/cpanel/cpanel"
DIRECTADMIN="/usr/local/directadmin/custombuild/build"
PLESK="/usr/local/psa/version"

# Set colors
REMOVE='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
WHITE='\e[39m'

trap ctrl_c INT
ctrl_c(){
    echo ""
    _show_log -d -y " [WARN]" -w " You press Ctrl + C. Exit!"
    exit 0
}

# Print log
_print_log(){
    if [ ${SUM_ARG} -eq ${OPTIND} ]
    then
        printf "$1${OPTARG}${REMOVE}""\n" | tee -a ${LOG_FILE}
    else
        printf "$1${OPTARG}${REMOVE}" | tee -a ${LOG_FILE}
    fi
}

# Show log
_show_log(){
    OPTIND=1
    SUM_ARG=$(($#+1))
    while getopts 'r:g:y:w:d' OPTION
    do
        case ${OPTION} in
            d)  _print_log "`date "+[ %d/%m/%Y %H:%M:%S ]"`" ;;
            r)  _print_log "${RED}" ;;
            g)  _print_log "${GREEN}" ;;
            y)  _print_log "${YELLOW}" ;;
            w)  _print_log "${WHITE}" ;;
        esac
    done
}

# Check network
_check_network(){
    _show_log -d -g " [INFO]" -w " Cheking network..."
    curl -sI raw.githubusercontent.com >/dev/null
    if [ $? -eq 0 ]
    then
        _show_log -d -g " [INFO]" -w " Connect Github successful!"
    else
        _show_log -d -r " [FAIL]" -w " Can not connect to Github file, please check your network. Exit!"
        exit 1
    fi
}

# Start time
_start_install(){
    TIME_BEGIN=`date +%s`
    _show_log -w "---"    
}

# End time
_end_install(){
    TIME_END=`date +%s`
    TIME_RUN=`date -d@$(( ${TIME_END} - ${TIME_BEGIN} )) -u +%Hh%Mm%Ss`
    _show_log -d -g " [INFO]" -w " Run time: ${TIME_RUN}"
    if [ -f /tmp/show_info_after_install.txt ]
    then
        echo ""
        cat /tmp/show_info_after_install.txt
    fi
    rm -f /tmp/{config_service.txt,config_service_min.txt,extra_service.txt,extra_service_min.txt,show_info.txt,php_version.txt,php_version_min.txt,security_service.txt,security_service_min.txt,show_info_after_install.txt}
}

# Create necessary directory
_create_dir(){
    if [ ! -d /var/mce/log ]
    then
        mkdir -p /var/mce/log
    fi
    if [ ! -d ${DEFAULT_DIR_WEB} ]
    then
        mkdir -p ${DEFAULT_DIR_WEB}
    fi
}

# Check if cPanel, DirectAdmin, Plesk has installed before
_check_control_panel(){
    _show_log -d -g " [INFO]" -w " Checking if cPanel, DirectAdmin, Plesk has installed before..."
    if [ -f ${CPANEL} ]
    then
        _show_log -d -r " [FAIL]" -w " Detected cPanel is installed on this server. Please use minimal OS without any control panel to use buildmce !"
        exit 1
    elif [ -f ${DIRECTADMIN} ]
    then
        _show_log -d -r " [FAIL]" -w " Detected DirectAdmin is installed on this server. Please use minimal OS without any control panel to use buildmce !"
        exit 1
    elif [ -f ${PLESK} ]
    then
        _show_log -d -r " [FAIL]" -w " Detected Plesk is installed on this server. Please use minimal OS without any control panel to use buildmce !"
        exit 1
    else
        _show_log -d -g " [INFO]" -w " No control panel detected. Continue..."
    fi
}

# Check option in a list
_check_value_in_list(){
    NAME=$1
    VALUE=$2
    List_VALUE=($3)
    false
    for i_CHECK_VALUE in ${List_VALUE[*]}
    do
        if [ "${i_CHECK_VALUE}" == "${VALUE}" ]
        then
            true
            break
        else
            false
        fi
    done
    if [ $? -ne 0 ]
    then
        _show_log -d -r " [FAIL]" -w " Not support $1: $2. Only support $1: $(echo ${List_VALUE[*]})"
        exit 1
    fi
}

# Check installed service
_check_installed_service(){
    CHECK_SERVICE=`command -v $1`
    if [ "$2" == "new"  ]
    then
        if [ -z ${CHECK_SERVICE} ]
        then
            _show_log -d -r " [FAIL]" -w " Can not install $1. Exit"
            exit 1
        else
            _show_log -d -g " [INFO]" -w " Install $1 sucessful!"
        fi
    else
        if [ -z ${CHECK_SERVICE} ]
        then
            _show_log -d -r " [FAIL]" -w " $1 is not installed!"
            return 1
        else
            _show_log -d -g " [INFO]" -w " $1 is installed!"
            return 0
        fi
    fi
}

# Detect web server
_detect_web_server(){
    if [ -z "${WEB_SERVER}" ]
    then
        _show_log -d -g " [INFO]" -w " Detecting web server..."
        if [ -z "${GET_WEB_SERVER}" ]
        then
            CHECK_NGINX_RUNNING=`_check_service -r nginx`
            CHECK_OLS_RUNNING=`_check_service -r litespeed`
            if [ ${CHECK_NGINX_RUNNING} -eq 1 ]
            then
                _show_log -d -g " [INFO]" -w " Detected nginx running."
                WEB_SERVER="nginx"
            elif [ ${CHECK_OLS_RUNNING} -eq 1 ]
            then
                _show_log -d -g " [INFO]" -w " Detected openlitespeed running."
                WEB_SERVER="openlitespeed"
            else
                _show_log -d -g " [INFO]" -w " Can not detect web server is running!"
                echo ""
                echo "Do you want to install $1 for nginx or openlitespeed?"
                echo "1. nginx"
                echo "2. openlitespeed"
                read -p "Your choice: " WEB_SERVER_CHOICE
                until [[ "${WEB_SERVER_CHOICE}" == 1 ]] || [[ "${WEB_SERVER_CHOICE}" == 2 ]]
                do
                    echo "Please choose 1 or 2!"
                    read -p "Your choice: " WEB_SERVER_CHOICE
                done
                if [ ${WEB_SERVER_CHOICE} -eq 1 ]
                then
                    WEB_SERVER="nginx"
                else
                    WEB_SERVER="openlitespeed"
                fi
                _show_log -d -g " [INFO]" -w " You choose web server" -r " ${WEB_SERVER}"
            fi
        else
            WEB_SERVER=${GET_WEB_SERVER}
            _show_log -d -g " [INFO]" -w " Web server is ${GET_WEB_SERVER}."
        fi
    fi
}

# Detect service running port 80
_detect_port_80(){
    _show_log -d -g " [INFO]" -w " Detecting service is running at port 80..."
    CHECK_PORT_80=`netstat -lntp | grep -e " 0.0.0.0:80 " -e " 127.0.0.1:80 " -e " :::80 " | awk '{print $7}' | cut -d"/" -f2 | sed 's/://' | sed 's/.conf//' | uniq`
    if [ -z ${CHECK_PORT_80} ]
    then
        _show_log -d -g " [INFO]" -w " No service is running at port 80."
    else
        _show_log -d -g " [INFO]" -w " Detected ${CHECK_PORT_80} is running at port 80!"
        if [ "${CHECK_PORT_80}" != "$1" ]
        then
            _show_log -d -g " [INFO]" -w " Trying stop ${CHECK_PORT_80}..."
            if [ -f /bin/systemctl ]
            then
                systemctl stop ${CHECK_PORT_80}
            else
                service ${CHECK_PORT_80} stop
            fi
            CHECK_PORT_80_AGAIN=`netstat -lntp | grep -e " 0.0.0.0:80 " -e " 127.0.0.1:80 " -e " :::80 " | awk '{print $7}' | cut -d"/" -f2 | sed 's/://' | sed 's/.conf//' | uniq`
            if [ ! -z ${CHECK_PORT_80_AGAIN} ]
            then
                _show_log -d -y " [WARN]" -w " Can not stop ${CHECK_PORT_80}!"
                CANNOT_STOP_PORT_80=1
            else
                _show_log -d -g " [INFO]" -w " Stop ${CHECK_PORT_80} sucessful!"
            fi
        fi    
    fi
}

# Check Information
_check_info(){
    _show_log -d -g " [INFO]" -w " Checking input options..."
    if [ "${INSTALL_ALL}" == "1" ]
    then
        GET_FTP_SERVER=${DEFAULT_FTP_SERVER}
        GET_PHP_VERSION=${DEFAULT_PHP_VERSION}
        echo "${DEFAULT_PHP_VERSION}" > /tmp/php_version.txt
        GET_NODEJS=${DEFAULT_NODEJS}
        GET_MARIADB=${DEFAULT_SQL_SERVER}
        GET_WEB_SERVER=${DEFAULT_WEB_SERVER}
        EXTRA_SERVICE="all"
        for i_EXTRA_SERVICE in ${List_EXTRA[*]}
        do
            if [ "${i_EXTRA_SERVICE}" != "all" ]
            then
                echo ${i_EXTRA_SERVICE} >> /tmp/extra_service.txt
            fi
        done
        SECURITY_SERVICE="all"
        for i_SECURITY_SERVICE in ${List_SECURITY[*]}
        do
            if [ "${i_SECURITY_SERVICE}" != "all" ]
            then
                echo ${i_SECURITY_SERVICE} >> /tmp/security_service.txt
            fi
        done
    elif [ ! -z "${GET_STACK}" ]
    then
        _check_value_in_list "Stack" "${GET_STACK}" "${List_STACK[*]}"
        GET_FTP_SERVER=${DEFAULT_FTP_SERVER}
        GET_PHP_VERSION=${DEFAULT_PHP_VERSION}
        echo "${DEFAULT_PHP_VERSION}" > /tmp/php_version.txt        
        GET_MARIADB=${DEFAULT_SQL_SERVER}
        if [ "${GET_STACK}" == "lemp" ]
        then
            GET_WEB_SERVER="nginx"
        else
            GET_WEB_SERVER="openlitespeed"
        fi
        unset GET_NODEJS EXTRA_SERVICE
        EXTRA_SERVICE="${GET_STACK}"
        for i_EXTRA_SERVICE in csf phpmyadmin letsencrypt memcached
        do
            echo "${i_EXTRA_SERVICE}" >> /tmp/extra_service.txt
        done
    fi
    
    if [ ! -z "${GET_FTP_SERVER}" ]
    then
        _check_value_in_list "FTP server" "${GET_FTP_SERVER}" "${List_FTP[*]}"
        echo "FTP server    : ${GET_FTP_SERVER}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_PHP_VERSION}" ]
    then
        cat /tmp/php_version.txt | sort | uniq > /tmp/php_version_min.txt
        for i_GET_PHP_VERSION in $(cat /tmp/php_version_min.txt)
        do
            _check_value_in_list "PHP version" "${i_GET_PHP_VERSION}" "${List_PHP[*]}"
        done
        echo "PHP version   : $(cat /tmp/php_version_min.txt | sed ':a;N;$!ba;s/\n/,/g')" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_NODEJS}" ]
    then
        _check_value_in_list "Nodejs version" "${GET_NODEJS}" "${List_NODEJS[*]}"
        echo "Nodejs version: ${GET_NODEJS}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_MARIADB}" ]
    then
        _check_value_in_list "SQL version" "${GET_MARIADB}" "${List_SQL[*]}"
        echo "SQL version   : ${GET_MARIADB}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        _check_value_in_list "Web server" "${GET_WEB_SERVER}" "${List_WEB[*]}"
        echo "Web server    : ${GET_WEB_SERVER}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${EXTRA_SERVICE}" ]
    then
        cat /tmp/extra_service.txt | sort | uniq > /tmp/extra_service_min.txt
        for i_EXTRA_SERVICE in $(cat /tmp/extra_service_min.txt)
        do
            _check_value_in_list "Extra service" "${i_EXTRA_SERVICE}" "${List_EXTRA[*]}"
        done
        echo "Extra services: $(cat /tmp/extra_service_min.txt | sed ':a;N;$!ba;s/\n/,/g')" >> /tmp/show_info.txt
    fi
    if [ ! -z "${SECURITY_SERVICE}" ]
    then
        cat /tmp/security_service.txt | sort | uniq > /tmp/security_service_min.txt
        for i_SECURITY_SERVICE in $(cat /tmp/security_service_min.txt)
        do
            _check_value_in_list "Security service" "${i_SECURITY_SERVICE}" "${List_SECURITY[*]}"
        done
        echo "Security services: $(cat /tmp/security_service_min.txt | sed ':a;N;$!ba;s/\n/,/g')" >> /tmp/show_info.txt
    fi
    if [ ! -f /tmp/show_info.txt ]
    then
        echo ""
        _show_log -d -r " [FAIL]" -w " Wrong command:" -r " sh ${SCRIPT_NAME} ${ALL_OPTIONS}" -w " Please check again! Exit."
        sleep 2
        _show_help
        exit 1
    fi
    _show_log -d -g " [INFO]" -w " Check input options sucessful!"
    _show_log -d -g " [INFO]" -w " Run command:" -r " sh ${SCRIPT_NAME} ${ALL_OPTIONS}"
    echo ""
    echo "We will install following services:"
    echo "---"
    cat /tmp/show_info.txt
    echo ""
    echo -e "If that is exactly what you need, please type ${GREEN}Yes${REMOVE} with caption ${GREEN}Y${REMOVE} to install or press ${RED}Ctrl + C${REMOVE} to cancel!"
    CHOICE_INSTALL="No"
    read -p "Your choice: " CHOICE_INSTALL
    while [ "${CHOICE_INSTALL}" != "Yes" ]
    do
        echo -e "Please type ${GREEN}Yes${REMOVE} with caption ${GREEN}Y${REMOVE} to install or press ${RED}Ctrl + C${REMOVE} to cancel!"
        read -p "Your choice: " CHOICE_INSTALL
    done
}

# Pre-install
_pre_install(){
    # Check DNS
    echo ""
    _show_log -d -g " [INFO]" -w " Installing require packages..."
    sleep 1
    sed -i 's/nameserver/#nameserver/g' /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    
    # Off SELINUX
    if [ -f /bin/systemctl ]
    then
        systemctl stop firewalld
        systemctl disable firewalld
    else
        service iptables stop
        chkconfig iptables off
    fi

    mv /etc/selinux/config /etc/selinux/config.orig
    cat /etc/selinux/config.orig | sed 's/^SELINUX/#SELINUX/g' > /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
    echo "SELINUXTYPE=targeted" >> /etc/selinux/config

    # Install some require packages
    yum -y install wget unzip net-tools epel-release
    rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-${OS_VER}.rpm
    echo ""
    _show_log -d -g " [INFO]" -w " Install require packages sucessful!"
}

# Update system
_update_sys(){
    _show_log -d -g " [INFO]" -w " Updating system..."
    sleep 1
    yum -y update
    _show_log -d -g " [INFO]" -w " Update system sucessful!"
}

#Install Services
##Install PHP
_install_php(){
    if [ ! -z "${GET_PHP_VERSION}" ]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Installing PHP..."
        sleep 1
        _detect_web_server php
        if [ "${WEB_SERVER}" == "nginx" ]
        then
            PHP_PREFIX="php"
            PHP_SUFFIX="-php"
            yum -y install centos-release-scl-rh
            yum -y --enablerepo=centos-sclo-rh-testing install devtoolset-6-gcc-c++
        else
            PHP_PREFIX="lsphp"
            PHP_SUFFIX=""
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OS_VER}.noarch.rpm
        fi
        
        for i_INSTALL_PHP in $(cat /tmp/php_version_min.txt)
        do
            PHP_VERSION_MIN=`echo ${i_INSTALL_PHP} | sed 's/\.//'`
            echo ""
            _show_log -d -g " [INFO]" -w " Installing php${PHP_VERSION_MIN}..."
            if [ "${WEB_SERVER}" == "nginx" ]
            then
                PHP_ENABLE_REPO="--enablerepo=remi-php${PHP_VERSION_MIN}"
            else
                PHP_ENABLE_REPO=""
            fi
            yum -y ${PHP_ENABLE_REPO} install \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX} \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-fpm \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-curl \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-devel \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-exif \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-fileinfo \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-filter \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-gd \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-hash \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-imap \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-intl \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-json \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-mbstring \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-mcrypt \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-mysqlnd \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-session \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-soap \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-simplexml \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-xml \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-xmlrpc \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-xsl \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-zip \
                ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-zlib 
    
            if [ "${WEB_SERVER}" == "nginx" ]
            then
                if [[ "${PHP_VERSION_MIN}" == "54" ]] || [[ "${PHP_VERSION_MIN}" == "55" ]]
                then
                    REMI_DIR="/etc/opt/remi"
                    if [ ! -d ${REMI_DIR} ]
                    then
                        mkdir ${REMI_DIR}
                    fi
                    ln -sf /opt/remi/php${PHP_VERSION_MIN}/root/etc ${REMI_DIR}/php${PHP_VERSION_MIN}
                fi
                echo ""
                _check_installed_service "php${PHP_VERSION_MIN}" "new"   
            else
                if [ -f /usr/local/lsws/lsphp${PHP_VERSION_MIN}/bin/lsphp ]
                then
                    echo ""
                    _show_log -d -g " [INFO]" -w " Install php${PHP_VERSION_MIN} sucessful!"
                else
                    _show_log -d -r " [FAIL]" -w " Can not install php${PHP_VERSION_MIN}. Exit"
                    exit 1
                fi
            fi
        done
    fi
}

# Install webserver
_install_web(){
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Installing Web server..."
        sleep 1
        if [ "${GET_WEB_SERVER}" == "nginx" ]
        then
            cat > "/etc/yum.repos.d/nginx.repo" <<EONGINXREPO
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
EONGINXREPO
        
            yum -y install nginx
            echo ""
            _detect_port_80 nginx
            if [ -z "${CANNOT_STOP_PORT_80}" ]
            then
                _restart_services nginx
            fi
            _start_on_boot nginx
        elif [ "${GET_WEB_SERVER}" == "openlitespeed" ]
        then
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OS_VER}.noarch.rpm
            yum -y install openlitespeed lsphp73-intl lsphp73-json lsphp73-devel lsphp73-soap lsphp73-xmlrpc lsphp73-zip
            ln -sf /usr/local/lsws/bin/openlitespeed /usr/local/bin/openlitespeed
            echo ""
            _detect_port_80 openlitespeed
            if [ -z "${CANNOT_STOP_PORT_80}" ]
            then
                sed -i 's/:8088$/:80/' ${LSWS_DIR}/conf/httpd_config.conf
                _restart_services openlitespeed
            fi
        fi
        _check_installed_service "${GET_WEB_SERVER}" "new"
    fi
}

##Install MariaDB
_install_mariadb(){    
    if [ ! -z "${GET_MARIADB}" ]
    then
        CHECK_SQL_SERVER=`_check_service -i "mysql"`
        if [ ${CHECK_SQL_SERVER} -ne 0 ]
        then
            echo ""
            _show_log -d -y " [WARN]" -w " MySQL installed. Do not install new!"
            NOT_CONFIG_MYSQL=1
        else
            echo ""
            _show_log -d -g " [INFO]" -w " Installing SQL server..."
            sleep 1
            # Check yum.mariadb.org
            HOST="yum.mariadb.org"
            if ping -c 1 -w 1 ${HOST} > /dev/null
            then
                if [ "${OS_ARCH}" == "x86_64" ]
                then
                    OS_ARCH1="amd64"
                elif [ "${OS_ARCH}" == "i686" ]
                then
                    OS_ARCH1="x86"
                fi
                cat > "/etc/yum.repos.d/MariaDB.repo" <<EOMARIADBREPO
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/${GET_MARIADB}/centos${OS_VER}-${OS_ARCH1}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOMARIADBREPO

                yum -y install MariaDB-server MariaDB-client
            else
                _show_log -d -r " [FAIL]" -w " Can not connect to yum.mariadb.org! Exit"
                exit 1
            fi
            echo ""
            _check_installed_service "mysql" "new"            
            CHECK_MARIADB=`mysql -V | grep MariaDB | wc -l`
            if [ ${CHECK_MARIADB} = 1 ]
            then
                if [ "${GET_MARIADB}" == "10.4" ]
                then
                    MYSQL="mariadb"
                else
                    MYSQL="mysql"
                fi
            else
                MYSQL="mysqld"
            fi
            _restart_services ${MYSQL}
            _start_on_boot ${MYSQL}
        fi
    fi
}

##Install phpMyAdmin
_install_phpmyadmin(){
    echo ""
    _show_log -d -g " [INFO]" -w " Installing phpMyAdmin..."
    sleep 1
    if [ "${GET_PHP_VERSION}" == "all" ]
    then
        PMD_VERSION=${PMD_VERSION_MAX}
    else
        _detect_web_server phpMyAdmin
        _show_log -d -g " [INFO]" -w " Detecting PHP version installed..."
        if [ "${WEB_SERVER}" = nginx ]
        then
            PHP_PREFIX="php"
            PHP_DIR="${REMI_DIR}"
        else
            PHP_PREFIX="lsphp"
            PHP_DIR="${LSWS_DIR}"
        fi
        CHECK_PHP_INSTALLED=`ls -1 ${PHP_DIR} | wc -l`
        if [ ${CHECK_PHP_INSTALLED} -eq 0 ]
        then
            _show_log -d -r " [FAIL]" -w " Can not detect PHP version! Exit"
            exit 1
        else
            _show_log -d -g " [INFO]" -w " List PHP version: $(ls -1 ${PHP_DIR} | grep "${PHP_PREFIX}[0-9][0-9]" | sed "s/${PHP_PREFIX}//" | sed ':a;N;$!ba;s/\n/,/g')"
        fi
        for i_INSTALL_PHPMYADMIN in $(ls -1 ${PHP_DIR} | grep "${PHP_PREFIX}[0-9][0-9]" | sed "s/${PHP_PREFIX}//")
        do
            if [ ${i_INSTALL_PHPMYADMIN} -eq 54 ]
            then
                PMD_VERSION="4.0.10.20"
            elif [ ${i_INSTALL_PHPMYADMIN} -lt 71 ]
            then
                PMD_VERSION=${PMD_VERSION_COMMON}
            else
                PMD_VERSION=${PMD_VERSION_MAX}
            fi
        done
        PHP_VERSION_PMD=`awk "BEGIN {printf \"%.1f\n\", ${i_INSTALL_PHPMYADMIN} / 10}"`
        _show_log -d -g " [INFO]" -w " Highest PHP version is ${PHP_VERSION_PMD}. We will install phpMyAdmin ${PMD_VERSION}"
        wget -O ${HOME}/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PMD_VERSION}/phpMyAdmin-${PMD_VERSION}-all-languages.tar.gz
        for i_PHPMYADMIN_DIR in ${HOME}/phpmyadmin ${HOME}/phpMyAdmin-${PMD_VERSION}-all-languages ${DEFAULT_DIR_WEB}/phpmyadmin
        do
            if [ -e ${i_PHPMYADMIN_DIR} ]
            then
                rm -rf ${i_PHPMYADMIN_DIR}
            fi
        done
        tar -xf ${HOME}/phpmyadmin.tar.gz
        rm -f ${HOME}/phpmyadmin.tar.gz
        mv ${HOME}/phpMyAdmin-${PMD_VERSION}-all-languages ${HOME}/phpmyadmin
        mv ${HOME}/phpmyadmin ${DEFAULT_DIR_WEB}
        mv ${DEFAULT_DIR_WEB}/phpmyadmin/config.sample.inc.php ${DEFAULT_DIR_WEB}/phpmyadmin/config.inc.php
        chown -R root:root ${DEFAULT_DIR_WEB}/phpmyadmin
    fi
    echo ""
    _show_log -d -g " [INFO]" -w " Install phpMyadmin sucessful!"
}


##Install FTP
_install_ftp(){
    if [ ! -z "${GET_FTP_SERVER}" ]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Installing ${GET_FTP_SERVER}..."
        sleep 1
        yum -y install ${GET_FTP_SERVER}
        echo ""
        _check_installed_service "${GET_FTP_SERVER}" "new"
        _restart_services ${GET_FTP_SERVER}
        _start_on_boot ${GET_FTP_SERVER}
    fi
}

# Install csf
_install_csf(){
    echo ""
    _show_log -d -g " [INFO]" -w " Installing csf..."
    sleep 1
    yum -y install perl-libwww-perl perl-LWP-Protocol-https bind-utils
    curl -o ${DIR}/csf.tgz https://download.configserver.com/csf.tgz
    tar -xf csf.tgz
    cd ${DIR}/csf
    sh install.sh   
    cd ${DIR}
    rm -rf csf*
    echo ""
    _check_installed_service "csf" "new"
}

# Install ImunifyAV
_install_imunify(){
    echo ""
    _show_log -d -g " [INFO]" -w " Installing ImunifyAV..."
    if [ ! -d /etc/sysconfig/imunify360 ]
    then
        mkdir -p /etc/sysconfig/imunify360
    fi
    cat > /etc/sysconfig/imunify360/integration.conf <<EOF
[PATHS]
UI_PATH = /var/www/html/ImunifyAV

[paths]
ui_path = /var/www/html/ImunifyAV
EOF
    cd ${DIR}
    wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
    bash imav-deploy.sh
    rm -f imav-deploy.sh
    echo ""
    _check_installed_service "imunify-antivirus" "new"
    _restart_services imunify-antivirus
    _start_on_boot imunify-antivirus
}

# Install Let's Encrypt
_install_letsencrypt(){
    echo ""
    _show_log -d -g " [INFO]" -w " Installing Let's Encrypt (certbot)..."
    yum -y install certbot
    echo ""
    _check_installed_service "certbot" "new"
    certbot register --register-unsafely-without-email <<EOF
A
EOF
}

# Install memcached or redis
_install_memcached_redis(){
    SERVICE_NAME=$1
    echo ""
    _show_log -d -g " [INFO]" -w " Installing ${SERVICE_NAME}..."
    _detect_web_server "php ${SERVICE_NAME} extension"
    if [ "${WEB_SERVER}" = nginx ]
    then
        PHP_PREFIX="php"
        PHP_DIR="${REMI_DIR}"
        PHP_SUFFIX="-php"
    else
        PHP_PREFIX="lsphp"
        PHP_DIR="${LSWS_DIR}"
        PHP_SUFFIX="-pecl"
    fi
    if [ -z "${GET_PHP_VERSION}" ]
    then
        _show_log -d -g " [INFO]" -w " Detecting PHP version installed..."
        CHECK_PHP_INSTALLED=`ls -1 ${PHP_DIR} | wc -l`
        if [ ${CHECK_PHP_INSTALLED} -eq 0 ]
        then
            _show_log -d -r " [FAIL]" -w " Can not detect PHP version! Exit"
            exit 1
        else
            _show_log -d -g " [INFO]" -w " List PHP version: $(ls -1 /usr/local/lsws | grep "lsphp[0-9][0-9]" | sed "s/lsphp//" | sed ':a;N;$!ba;s/\n/,/g')"
        fi
        PHP_VERSION_MCD=$(ls -1 ${PHP_DIR} | grep "${PHP_PREFIX}[0-9][0-9]" | sed "s/${PHP_PREFIX}//")
    else
        PHP_VERSION_MCD=$(cat /tmp/php_version_min.txt)
    fi
    if [ "${SERVICE_NAME}" == "memcached" ]
    then
        yum -y install memcached libmemcached
    else
        yum -y install redis
    fi
    for i_INSTALL_MEMCACHED_REDIS in $(echo ${PHP_VERSION_MCD})
    do
        echo ""
        PHP_VERSION_MIN=`echo ${i_INSTALL_MEMCACHED_REDIS} | sed 's/\.//'`
        _show_log -d -g " [INFO]" -w " Installing php ${SERVICE_NAME} extension for php${PHP_VERSION_MIN}..."
        if [ "${WEB_SERVER}" == "nginx" ]
        then
            PHP_ENABLE_REPO="remi-php${PHP_VERSION_MIN}"
            PHP_BIN="php${PHP_VERSION_MIN}"
        else
            PHP_ENABLE_REPO="litespeed"
            PHP_BIN="${LSWS_DIR}/lsphp${PHP_VERSION_MIN}/bin/php"
        fi
        yum -y --enablerepo=${PHP_ENABLE_REPO} install ${PHP_PREFIX}${PHP_VERSION_MIN}${PHP_SUFFIX}-${SERVICE_NAME}
        CHECK_PHP_SERVICE=`${PHP_BIN} -m | grep -c "^${SERVICE_NAME}$"`
        if [ ${CHECK_PHP_SERVICE} -ne 0 ]
        then
            _show_log -d -g " [INFO]" -w " Install php ${SERVICE_NAME} extension for php${PHP_VERSION_MIN} sucessful!"
        else
            _show_log -d -r " [FAIL]" -w " Can not install php ${SERVICE_NAME} extension for php${PHP_VERSION_MIN}"
        fi
    done
    if [ "${SERVICE_NAME}" == "memcached" ]
    then
        _check_installed_service "memcached" "new"
    else
        _check_installed_service "redis-server" "new"
    fi
    _restart_services ${SERVICE_NAME}
    _start_on_boot ${SERVICE_NAME}
}

# Install memcached
_install_memcached(){
    _install_memcached_redis memcached
}

# Install redis
_install_redis(){
    _install_memcached_redis redis
}

# Install Node.js
_install_nodejs(){
    if [ ! -z "${GET_NODEJS}" ]
    then
        CHECK_NODEJS=`node -v 2>/dev/null`
        if [ ! -z ${CHECK_NODEJS} ]
        then
            echo ""
            _show_log -d -y " [WARN]" -w " Node.js ${CHECK_NODEJS} installed. Do not install new!"
            NOT_CONFIG_NODEJS=1
        else
            _show_log -d -g " [INFO]" -w " Installing Node.js ${GET_NODEJS}..."
            yum -y install make gcc-c++
            curl -sL https://rpm.nodesource.com/setup_${GET_NODEJS} | bash -
            yum clean metadata
            yum -y install nodejs
            _check_installed_service "node" "new"
        fi
    fi
}

# Install vnstat
_install_vnstat(){
    echo ""
    _show_log -d -g " [INFO]" -w " Installing vnstat..."
    yum -y install gcc sqlite-devel
    cd ${DIR}
    curl -o vnstat-${DEFAULT_VNSTAT_VERSION}.tar.gz https://humdi.net/vnstat/vnstat-${DEFAULT_VNSTAT_VERSION}.tar.gz
    tar -xf vnstat-${DEFAULT_VNSTAT_VERSION}.tar.gz
    cd vnstat-${DEFAULT_VNSTAT_VERSION}
    ./configure
    make
    make install
    cd ${DIR}
    rm -rf vnstat-${DEFAULT_VNSTAT_VERSION}*
    _check_installed_service "vnstat" "new"
}

# Config services
##Config PHP
_config_php(){
    if [ ! -z "${GET_PHP_VERSION}" ]
    then
        _show_log -d -g " [INFO]" -w " Configing PHP..."
        sleep 1
        for i_CONFIG_PHP in $(cat /tmp/php_version_min.txt)
        do
            _show_log -d -g " [INFO]" -w " Configing php${PHP_VERSION_MIN}..."
            PHP_VERSION_MIN=`echo ${i_CONFIG_PHP} | sed 's/\.//'`           
            if [ "${WEB_SERVER}" == "nginx" ]
            then
                PHP_INI_DIR="${REMI_DIR}/php${PHP_VERSION_MIN}"
            else
                PHP_INI_DIR="/usr/local/lsws/lsphp${PHP_VERSION_MIN}/etc"
            fi
            mv ${PHP_INI_DIR}/php.ini ${PHP_INI_DIR}/php.ini.orig
            cat ${PHP_INI_DIR}/php.ini.orig | sed \
                "s/memory_limit = 128M/memory_limit = 256M/; \
                s/upload_max_filesize = 2M/upload_max_filesize = 200M/; \
                s/post_max_size = 8M/post_max_size = 200M/; \
                s/max_execution_time = 30/max_execution_time = 300/; \
                s/max_input_time = 60/max_input_time = 300/; \
                s/; max_input_vars = 1000/max_input_vars = 10000/" > ${PHP_INI_DIR}/php.ini
            if [ "${WEB_SERVER}" == "nginx" ]
            then    
                sed -i "s/^listen =.*/listen = \/var\/run\/php${PHP_VERSION_MIN}.sock/" ${PHP_INI_DIR}/php-fpm.d/www.conf
                rm -f /var/run/php${PHP_VERSION_MIN}.sock
                _restart_services php${PHP_VERSION_MIN}-php-fpm
                _start_on_boot php${PHP_VERSION_MIN}-php-fpm
            fi
            _show_log -d -g " [INFO]" -w " Config php${i_CONFIG_PHP} sucessful!"
        done
        CHECK_OLS_RUN=`_check_service -r "litespeed"`
        if [[ "${WEB_SERVER}" == "openlitespeed" ]] && [[ ${CHECK_OLS_RUN} -ne 0 ]]
        then
            _restart_services openlitespeed
        fi
        _show_log -d -g " [INFO]" -w " Config PHP sucessful!"
    fi
}

## Config WEB server
###Config Nginx
_config_nginx(){
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        _show_log -d -g " [INFO]" -w " Configing nginx..."
        sleep 1
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
        cat > "/etc/nginx/nginx.conf" <<EONGINXCONF
worker_processes 1;
worker_rlimit_nofile 65536;
pid /var/run/nginx.pid;

events {
        worker_connections 1024;
}

http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;

        gzip on;
        gzip_disable "msie6";
        gzip_min_length  1100;
        gzip_buffers  4 32k;
        gzip_types    text/plain application/x-javascript text/xml text/css;

        open_file_cache          max=10000 inactive=10m;
        open_file_cache_valid    2m;
        open_file_cache_min_uses 1;
        open_file_cache_errors   on;

        ignore_invalid_headers on;
        client_max_body_size    8m;
        client_header_timeout  3m;
        client_body_timeout 3m;
        send_timeout     3m;
        connection_pool_size  256;
        client_header_buffer_size 4k;
        large_client_header_buffers 4 32k;
        request_pool_size  4k;
        output_buffers   4 32k;
        postpone_output  1460;
        log_format traffic '\$request_length \$bytes_sent ';

        include /etc/nginx/conf.d/*.conf;
}
EONGINXCONF

        echo "0 0 1 * * /var/mce/script/rotate_log" >> /var/spool/cron/root
        _show_log -d -g " [INFO]" -w " Config nginx sucessful!"
    fi
        _restart_services nginx
}

### Config OpenLiteSpeed
_config_openlitespeed(){
    _show_log -d -g " [INFO]" -w " Configing openlitespeed..."
    sleep 1
    sed -i 's/index.html$/index.html, index.php/' ${LSWS_DIR}/conf/vhosts/Example/vhconf.conf
    if [ -d "${DEFAULT_DIR_WEB}/phpmyadmin" ]
    then
        ln -sf ${DEFAULT_DIR_WEB}/phpmyadmin ${LSWS_DIR}/Example/html/phpmyadmin
        chown -R nobody.nobody ${DEFAULT_DIR_WEB}/phpmyadmin
    fi
    _restart_services openlitespeed
    OPS_ADMIN_PASS=`date +%s | sha256sum | base64 | head -c 12`
    /usr/local/lsws/admin/misc/admpass.sh <<EOF
admin
${OPS_ADMIN_PASS}
${OPS_ADMIN_PASS}
EOF
    
    if [ -f "/etc/csf/csf.conf" ]
    then
        _show_log -d -g " [INFO]" -w " Opening port 7080 in csf..."
        OLD_TCP_IN="$(cat /etc/csf/csf.conf | grep "^TCP_IN =" | cut -d'"' -f2)"
        CHECK_OLS_OPEN_PORT=`echo ",${OLD_TCP_IN}," | grep -c ",7080,"`
        if [ ${CHECK_OLS_OPEN_PORT} -eq 0 ]
        then
            sed -i "s/${OLD_TCP_IN}/${OLD_TCP_IN},7080/" /etc/csf/csf.conf
        fi
        CHECK_CSF_RUN=`csf -l | wc -l`
        if [ ${CHECK_CSF_RUN} -ne 1 ]
        then
            csf -r
        else
            _show_log -d -y " [WARN]" -w " csf is not running, do not restart csf!"
        fi
        _show_log -d -g " [INFO]" -w " Open port 7080 in csf sucessful!"
    fi
    echo "---" >> /tmp/show_info_after_install.txt
    echo "You can log in OpenLiteSpeed web admin with these informations:" >> /tmp/show_info_after_install.txt
    echo "https://${IPADDRESS}:7080" >> /tmp/show_info_after_install.txt
    echo "User: admin" >> /tmp/show_info_after_install.txt
    echo "Password: ${OPS_ADMIN_PASS}" >> /tmp/show_info_after_install.txt
    _show_log -d -g " [INFO]" -w " Config openlitespeed sucessful!"
}

## Config phpmyadmin
_config_phpmyadmin(){
    _show_log -d -g " [INFO]" -w " Configing phpmyadmin..."
    sleep 1
    PHP_VERSION_MIN=`echo ${PHP_VERSION_PMD} | sed 's/\.//'`
    FPM_DIR="${REMI_DIR}/php${PHP_VERSION_MIN}/php-fpm.d"
    BLOWFISH_SECRET=`date +%s | sha256sum | base64 | head -c 32`
    cat > "${DEFAULT_DIR_WEB}/phpmyadmin/config.inc.php" <<EOCONFIGINC
<?php
\$cfg['blowfish_secret'] = '${BLOWFISH_SECRET}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['connect_type'] = 'tcp';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['PmaNoRelation_DisableWarning'] = true;
\$cfg['VersionCheck'] = false;
EOCONFIGINC

    if [ "${WEB_SERVER}" == "nginx" ]
    then
        chown -R nginx.nginx ${DEFAULT_DIR_WEB}/phpmyadmin
        if [ ! -d ${FPM_DIR} ]
        then
            mkdir ${FPM_DIR}
        else
            mv ${FPM_DIR}/www.conf ${FPM_DIR}/www.conf.orig
        fi
        cat > "${FPM_DIR}/www.conf" <<EOconfig_php_fpm
[nginx]
user = nginx
group = nginx
listen = /var/run/php${PHP_VERSION_MIN}.sock
listen.owner = nginx
listen.group = nginx
php_admin_value[disable_functions] = passthru,shell_exec,system
php_admin_flag[allow_url_fopen] = off
pm = dynamic
pm.max_children = 25
pm.start_servers = 5
pm.min_spare_servers = 2
pm.max_spare_servers = 10
chdir = /
EOconfig_php_fpm
        
        _restart_services php${PHP_VERSION_MIN}-php-fpm

        if [ ! -d ${VHOST_DIR} ]
        then
            mkdir ${VHOST_DIR}
        fi

        if [ -f ${VHOST_DIR}/default.conf ]
        then
            mv ${VHOST_DIR}/default.conf ${VHOST_DIR}/default.conf.orig
        fi

        cat > "${VHOST_DIR}/_default_server.conf" <<EOnginx_vhost_default
server {
        listen       80;
        server_name  localhost;

        location / {
            root   /var/www/html;
            index  index.php index.html index.htm;
        }

        location ~ ^/phpmyadmin/(.*\\.php)\$ {
            root                /var/www/html/phpmyadmin/;
            fastcgi_index       index.php;
            fastcgi_pass        unix:/var/run/php${PHP_VERSION_MIN}.sock;
            include             fastcgi_params;
            fastcgi_param       SCRIPT_FILENAME /var/www/html/phpmyadmin/\$1;
            fastcgi_param       DOCUMENT_ROOT /var/www/html/phpmyadmin;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
}
EOnginx_vhost_default
    
        _restart_services nginx
    elif [ "${WEB_SERVER}" == "openlitespeed" ]
    then
        chown -R nobody.nobody ${DEFAULT_DIR_WEB}/phpmyadmin
    else
        _show_log -d -g " [INFO]" -w " Can not detect web server, do not chown phpmyadmin directory!"
    fi
    echo "---" >> /tmp/show_info_after_install.txt
    echo "You can log in phpmyadmin with these informations:" >> /tmp/show_info_after_install.txt
    echo "http://${IPADDRESS}/phpmyadmin" >> /tmp/show_info_after_install.txt
    echo "User: root" >> /tmp/show_info_after_install.txt
    echo "Password: $(cat /root/.my.cnf | grep "^password=" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g" | head -1)" >> /tmp/show_info_after_install.txt
    _show_log -d -g " [INFO]" -w " Config phpmyadmin sucessful!"
}

## Config MySQL
_config_mariadb(){
    if [[ ! -z "${GET_MARIADB}" ]] && [[ "${NOT_CONFIG_MYSQL}" != "1" ]]
    then
        _show_log -d -g " [INFO]" -w " Configing SQL..."
        sleep 1
        SQLPASS=`date +%s | sha256sum | base64 | head -c 12`
        if [ "${GET_MARIADB}" == "10.4" ]
        then
            /usr/bin/mysql_secure_installation << EOF
            
n
y
${SQLPASS}
${SQLPASS}
y
y
y
y
EOF
        else
            /usr/bin/mysql_secure_installation << EOF

y
${SQLPASS}
${SQLPASS}
y
y
y
y
EOF
        fi

        cat > "/root/.my.cnf" <<EOFMYCNF
[client]
user="root"
password="${SQLPASS}"
EOFMYCNF

        mv /etc/my.cnf /etc/my.cnf.orig
        cat > "/etc/my.cnf" <<EOFMYSQLCONF
[mysqld]
log_error=/var/lib/mysql/${HOSTNAME}.err
bind-address = 127.0.0.1
port    = 3306
socket  = /var/lib/mysql/mysql.sock
max_connections         = 300
max_connect_errors      = 10
max_allowed_packet      = 16M
sort_buffer_size        = 1M
join_buffer_size        = 2M
thread_cache_size       = 8
query_cache_size        = 64M
query_cache_limit       = 4M
query_cache_type        = 0
default-storage-engine = INNODB
thread_stack            = 240K
tmp_table_size          = 256M
max_heap_table_size = 256M
table_open_cache        = 800
key_buffer_size         = 32M
myisam_sort_buffer_size = 256M
myisam_repair_threads   = 1
innodb_buffer_pool_size         = 512M
innodb_thread_concurrency       = 16
innodb_lock_wait_timeout        = 120
innodb_buffer_pool_instances= 2

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size         = 256M
sort_buffer_size        = 256M
read_buffer             = 8M
write_buffer            = 8M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
open-files-limit        = 8192
EOFMYSQLCONF

        _restart_services ${MYSQL}
        echo ""
        _show_log -d -g " [INFO]" -w " Config SQL sucessful!"
    fi
}

## Config FTP
_config_ftp(){
    :
}
_config_csf(){
    _show_log -d -g " [INFO]" -w " Configing csf..."
    sed -i 's/TESTING = "1"/TESTING = "0"/; s/443,587/443,465,587/; s/RESTRICT_SYSLOG = "0"/RESTRICT_SYSLOG = "2"/' /etc/csf/csf.conf
    cat >> "/etc/csf/csf.pignore" <<EOCSF
exe:/usr/sbin/nginx
exe:/usr/sbin/php-fpm
exe:/usr/sbin/rpcbind
pexe:/usr/libexec/postfix/.*
pexe:/opt/remi/.*/root/usr/sbin/php-fpm
EOCSF
    csf -r
    echo ""
    _show_log -d -g " [INFO]" -w " Config csf sucessful!"
}

## Config webserver
_config_web(){
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        _config_${GET_WEB_SERVER}
    fi
}

## Config imunify
_config_imunify(){
    :
}

## Config Let's Encrypt
_config_letsencrypt(){
    :
}

## Config memcached
_config_memcached(){
    _show_log -d -g " [INFO]" -w " Configing memcached..."
    mv /etc/sysconfig/memcached /etc/sysconfig/memcached.orig
    cat /etc/sysconfig/memcached.orig | sed \
        "s/MAXCONN=.*/MAXCONN=\"10240\"/; \
        s/CACHESIZE=.*/CACHESIZE=\"256\"/; \
        s/OPTIONS=.*/OPTIONS=\"-l 127.0.0.1 -U 0\"/" > /etc/sysconfig/memcached
    _restart_services memcached
    _show_log -d -g " [INFO]" -w " Config memcached sucessful!"
}

## Config redis
_config_redis(){
    :
}

## Config Node.js
_config_nodejs(){
    :
}

## Config vnstat
_config_vnstat(){
    _show_log -d -g " [INFO]" -w " Configing vnstat..."
    NETWORK_CARD=`ip route get 1 | awk '{print $5; exit}'`
    sed -i "s/^Interface.*/Interface = \"${NETWORK_CARD}\"/" /usr/local/etc/vnstat.conf
    _show_log -d -g " [INFO]" -w " Config vnstat sucessful!"
}

# Restart service
_restart_services(){
    if [ -f /bin/systemctl ]
    then
        systemctl restart $1
    else
        service $1 restart
    fi
}

# Start service when boot
_start_on_boot(){
    if [ -f /bin/systemctl ]
    then
        systemctl enable $1
    else
        chkconfig $1 on
    fi
}

# Check services after install
_check_service(){
    case $1 in
        -i) command -v $2 | wc -l ;;
        -r) pidof $2 | wc -l ;;
    esac
}

# Download mce
_download_mce(){
    if [ "${DOWNLOAD_MCE}" == "2" ]
    then
        echo ""
        echo "---"
        echo -e "If you want use ${GREEN}mce${REMOVE} to auto create user, vhost, ssl... please type ${GREEN}Yes${REMOVE} with caption Y."
        false
        while [ $? -eq 1 ]
        do
            read -p "Your choice(Yes/No): " CHOICE_DOWNLOAD
            if [[ "${CHOICE_DOWNLOAD}" == "Yes" ]] || [[ "${CHOICE_DOWNLOAD}" == "No" ]]
            then
                true
            else
                echo -e "Please type ${GREEN}Yes${REMOVE} or ${RED}No${REMOVE}!"
                false
            fi
        done
    fi
    if [[ "${CHOICE_DOWNLOAD}" == "Yes" ]] || [[ "${DOWNLOAD_MCE}" == "1" ]]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Starting to download mce scripts..."
        sleep 1
        curl -o ${DIR}/mce_create ${GITHUB_LINK}/script/mce_create
        sh ${DIR}/mce_create
        rm -f ${DIR}/mce_create
        if [ ! -d ${BASH_DIR} ]
        then
            mkdir -p ${BASH_DIR}
        fi
        if [ "${DIR}" != "${BASH_DIR}" ]
        then
            mv ${DIR}/build.sh ${BASH_DIR}/build.sh
            chmod 755 ${BASH_DIR}/build.sh
        fi
        echo ""
        _show_log -d -g " [INFO]" -w " Download mce scripts successful!"
    elif [ "${CHOICE_DOWNLOAD}" == "No" ]
    then
        _show_log -d -g " [INFO]" -w " You do not download mce."
    fi
    if [ "${DOWNLOAD_MCE}" == "2" ]
    then
        echo ""
        echo -e "Everything is done! Please type ${GREEN}mce${REMOVE} to start create your amazing website!"
        echo -e "${RED}REMEMBER${REMOVE}: If this is the first you use buildmce, please reboot your server for system update all funtions!"
    fi
}

# Main install
_main_install(){
    _install_ftp
    _install_php
    _install_nodejs
    _install_mariadb
    _install_web
    if [ ! -z "${EXTRA_SERVICE}" ]
    then
        for i_EXTRA_SERVICE in $(cat /tmp/extra_service_min.txt)
        do
            _install_${i_EXTRA_SERVICE}
        done
    fi
    if [ ! -z "${SECURITY_SERVICE}" ]
    then
        for i_SECURITY_SERVICE in $(cat /tmp/security_service_min.txt)
        do
            _install_${i_SECURITY_SERVICE}
        done
    fi
    
    _config_ftp
    _config_php
    _config_mariadb
    _config_web
    if [ ! -z "${EXTRA_SERVICE}" ]
    then
        for i_EXTRA_SERVICE in $(cat /tmp/extra_service_min.txt)
        do
            _config_${i_EXTRA_SERVICE}
        done
    fi
    if [ ! -z "${SECURITY_SERVICE}" ]
    then
        for i_SECURITY_SERVICE in $(cat /tmp/security_service_min.txt)
        do
            _config_${i_SECURITY_SERVICE}
        done
    fi
}

# Show help
_show_help(){
    echo "Usage: sh ${SCRIPT_NAME} [options...]"
    echo "Options:"
    echo "    -a                   Install all services."
    echo ""
    echo "    -l [stack]           Choose stack will be installed(lemp=Linux+Nginx+MariaDB+PHP, lomp=Linux+OpenLiteSpeed+MariaDB+PHP)"
    echo "        stack:           $(echo ${List_STACK[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -e [extra]           Install extra services. Can use multiple -e options."
    echo "        extra:           $(echo ${List_EXTRA[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -f [ftp-server]      Choose ftp server will be installed."
    echo "        ftp-server:      $(echo ${List_FTP[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -m [mariadb-version] Choose MariaDB version will be installed."
    echo "        mariadb-server:  $(echo ${List_SQL[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -n [nodejs-version]  Choose Node.js version will be installed."
    echo "        nodejs-version:  $(echo ${List_NODEJS[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -p [php-version]     Choose php version will be installed. Can use multiple -p options."
    echo "        php-version:     $(echo ${List_PHP[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -s [security]        Install security services. Can use multiple -e options."
    echo "        security:        $(echo ${List_SECURITY[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -w [web-server]      Choose web server will be installed."
    echo "        web-server:      $(echo ${List_WEB[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -d                   Download mce script only."
    echo "    -u                   Update build.sh script to latest version."
    echo "    -h                   Show help"
    echo "    -v                   Show version"    
    echo ""
    echo "Example:"
    echo "    sh ${SCRIPT_NAME} -a"
    echo "    sh ${SCRIPT_NAME} -l lemp"
    echo "    sh ${SCRIPT_NAME} -p 7.3 -w nginx -m 10.4 -f proftpd -e phpmyadmin -s csf"
}

# Main
rm -f /tmp/{config_service.txt,config_service_min.txt,extra_service.txt,extra_service_min.txt,show_info.txt,php_version.txt,php_version_min.txt,security_service.txt,security_service_min.txt,show_info_after_install.txt}
while getopts 'e:f:l:m:n:p:s:w:aduhv' OPTION
do
    case ${OPTION} in
        a) INSTALL_ALL=1; DOWNLOAD_MCE=2 ;;
        d) DOWNLOAD_MCE=1
           _create_dir
           _start_install
           _check_network
           _download_mce
           exit 0
           ;;
        e) EXTRA_SERVICE=${OPTARG}
           if [ "${EXTRA_SERVICE}" == "all" ]
           then
               for i_EXTRA_SERVICE in ${List_EXTRA[*]}
               do
                   if [ "${i_EXTRA_SERVICE}" != "all" ]
                   then
                       echo ${i_EXTRA_SERVICE} >> /tmp/extra_service.txt
                   fi
               done
           else
               echo ${EXTRA_SERVICE} >> /tmp/extra_service.txt
           fi
           ;;
        f) GET_FTP_SERVER=${OPTARG} ;;
        l) GET_STACK=${OPTARG}; DOWNLOAD_MCE=2 ;;
        m) GET_MARIADB=${OPTARG} ;;
        n) GET_NODEJS=${OPTARG} ;;
        p) GET_PHP_VERSION=${OPTARG} 
           if [ "${GET_PHP_VERSION}" == "all" ]
           then
               for i_GET_PHP_VERSION in ${List_PHP[*]}
               do
                   if [ "${i_GET_PHP_VERSION}" != "all" ]
                   then
                       echo ${i_GET_PHP_VERSION} >> /tmp/php_version.txt
                   fi
               done
           else
               echo ${GET_PHP_VERSION} >> /tmp/php_version.txt
           fi
           ;;
        s) SECURITY_SERVICE=${OPTARG}
           if [ "${SECURITY_SERVICE}" == "all" ]
           then
               for i_SECURITY_SERVICE in ${List_SECURITY[*]}
               do
                   if [ "${i_SECURITY_SERVICE}" != "all" ]
                   then
                       echo ${i_SECURITY_SERVICE} >> /tmp/security_service.txt
                   fi
               done
           else
               echo ${i_SECURITY_SERVICE} >> /tmp/security_service.txt
           fi
           ;;
        u) rm -f $0
           curl -so build.sh ${GITHUB_LINK}/build.sh
           chmod 755 build.sh
           exit 0
           ;;
        w) GET_WEB_SERVER=${OPTARG} ;;
        h) _show_help
           exit 0
           ;;
        v) head -n 5 ${SCRIPT_NAME} | grep "^# Version:" | awk '{print $3}' ; exit 0 ;;
        *) _show_help; exit 1 ;;
    esac
done

_create_dir
_start_install
_check_network
_check_control_panel
_check_info
_update_sys
_pre_install
_main_install
_end_install
_download_mce
