#!/bin/bash
# Auto Install LAMP or LEMP on CentOS 6,7
# Version: 1.0
# Author: mbrother

# Set variables
SCRIPT_NAME=$0
OPTIONS="$@"
OS_VER=`rpm -E %centos`
OS_ARCH=`uname -m`
IPADDRESS=`ip route get 1 | awk '{print $NF;exit}'`
DIR=`pwd`
BASH_DIR="/var/mce/script"
OPTION=${1}
CPANEL="/usr/local/cpanel/cpanel"
DIRECTADMIN="/usr/local/directadmin/custombuild/build"
PLESK="/usr/local/psa/version"
GITHUB_LINK="https://raw.githubusercontent.com/mbrother2/buildmce/master"
LOG_FILE="/var/mce/log/install.log"
DEFAULT_DIR_WEB="/var/www/html"
REMI_DIR="/etc/opt/remi"
VHOST_DIR="/etc/nginx/conf.d"
List_PHP=(all 5.4 5.5 5.6 7.0 7.1 7.2 7.3 7.4)
List_SQL=(10.0 10.1 10.2 10.3 10.4)
List_FTP=(proftpd pure-ftpd)
List_WEB=(nginx openlitespeed)
List_EXTRA=(all csf phpmyadmin)
List_CONF=(all php sql web phpmyadmin)
PMD_VERSION_MAX="5.0.2"
PMD_VERSION_COMMON="4.9.5"

# Default services
DEFAULT_FTP_SERVER="pure-ftpd"
DEFAULT_PHP_VERSION="7.4"
DEFAULT_SQL_SERVER="10.4"
DEFAULT_WEB_SERVER="nginx"

# Color variables
REMOVE='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
WHITE='\e[39m'

# Show & write log
_print_log(){
    if [ ${SUM_ARG} -eq ${OPTIND} ]
    then
        printf "$1${OPTARG}${REMOVE}""\n" | tee -a ${LOG_FILE}
    else
        printf "$1${OPTARG}${REMOVE}" | tee -a ${LOG_FILE}
    fi
}

# Main function
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

# Multi languages
_multi_lang(){
    if [ ${CHOOSE_LANG} -eq 1 ]
    then
        curl -o ${DIR}/build.en ${GITHUB_LINK}/language/build.en
        source ${DIR}/build.en
    elif [ ${CHOOSE_LANG} -eq 2 ]
    then
        curl -o ${DIR}/build.vi ${GITHUB_LINK}/language/build.vi
        source ${DIR}/build.vi
    fi
}

# Check if cPanel, DirectAdmin, Plesk has installed before
_check_control_panel(){
    _show_log -d -g " [INFO]" -w " Checking if cPanel, DirectAdmin, Plesk has installed before..."
    if [[ -f ${CPANEL} ]] || [[ -f ${DIRECTADMIN} ]] || [[ -f ${PLESK} ]]
    then
        _show_log -d -r " [FAIL]" -w " ${LANG__check_control_panel1}"
        _show_log -d -r " [FAIL]" -w " ${LANG__check_control_panel2}"
        exit 1
    else
        _show_log -d -g " [INFO]" -w " No control panel detected. Continue!"
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

_yes_no(){
    if [ "${1}" != "Yes" ]
    then
        echo -e "${LANG_yes_no}"
    fi
}

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

_detect_web_server(){
    _show_log -d -g " [INFO]" -w " Detecting web server..."
    CHECK_NGINX_RUNNING=`_check_service -r nginx`
    if [ ${CHECK_NGINX_RUNNING} -eq 1 ]
    then
        _show_log -d -g " [INFO]" -w " Detected nginx running."
        return 11
    else
        CHECK_OPL_RUNNING=`_check_service -r litespeed`
        if [ ${CHECK_OPL_RUNNING} -eq 1 ]
        then
            _show_log -d -g " [INFO]" -w " Detected openlitespeed running."
            return 21
        else
            CHECK_NGINX_INSTALLED=`_check_service -i nginx`
            if [ ${CHECK_NGINX_INSTALLED} -eq 1 ]
            then
                _show_log -d -g " [INFO]" -w " Detected nginx installed but NOT running."
                return 10
            else
                CHECK_OPL_INSTALLED=`_check_service -i openlitespeed`
                if [ ${CHECK_NGINX_INSTALLED} -eq 1 ]
                then
                    _show_log -d -g " [INFO]" -w " Detected openlitespeed installed but NOT running."
                    return 20
                else
                    return 0
                fi
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
        GET_SQL_SERVER=${DEFAULT_SQL_SERVER}
        GET_WEB_SERVER=${DEFAULT_WEB_SERVER}
        EXTRA_SERVICE="all"
    fi
    if [ ! -z "${GET_FTP_SERVER}" ]
    then
        _check_value_in_list "FTP server" "${GET_FTP_SERVER}" "${List_FTP[*]}"
        echo "FTP server    : ${GET_FTP_SERVER}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_PHP_VERSION}" ]
    then
        _check_value_in_list "PHP version" "${GET_PHP_VERSION}" "${List_PHP[*]}"
        echo "PHP version   : ${GET_PHP_VERSION}" >> /tmp/show_info.txt
    fi
    if [ ! -z "${GET_SQL_SERVER}" ]
    then
        _check_value_in_list "SQL version" "${GET_SQL_SERVER}" "${List_SQL[*]}"
        echo "SQL version   : ${GET_SQL_SERVER}" >> /tmp/show_info.txt
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
    _show_log -d -g " [INFO]" -w " Check input options sucessful!"
    _show_log -d -g " [INFO]" -w " Run command: ${SCRIPT_NAME} ${OPTIONS}"
    echo ""
    cat /tmp/show_info.txt
}

# Pre-install
_pre_install(){
    # Check DNS
    echo ""
    _show_log -d -g " [INFO]" -w " Installing require packages..."
    sleep 2
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

    ##Install wget unzip
    yum -y install wget unzip epel-release
    _show_log -d -g " [INFO]" -w " Install require packages sucessful!"
}

# Let's go
_sync_time(){
    _show_log -d -g " [INFO]" -w " Syncing time..."
    yum -y install ntp
    rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime
    if [ -f /bin/systemctl ]
    then
        systemctl restart ntpd
        systemctl enable ntpd
    else
        service ntpd restart
        chkconfig ntpd on
    fi
    echo ""
    echo -e "${LANG__sync_time}"
    _show_log -d -g " [INFO]" -w " Waitting for 15 seconds..."
    sleep 15
    _show_log -d -g " [INFO]" -w " Sync time sucessful!"
}

_start_time(){
    RIGHT_NOW=`date +"%T %d-%m-%Y"`
    BEGIN_TIME=`date +%s`
    echo -e "${RED}[ ${RIGHT_NOW} ]${REMOVE}${LANG__start_time}"
    sleep 1
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
_install_php_single(){
    PHP_VERSION=$1
    echo ""
    _show_log -d -g " [INFO]" -w " Installing PHP ${PHP_VERSION}..."
    if [ "${WEB_SERVER}" == "nginx" ]
        then
            PHP_ENABLE_REPO="--enablerepo=remi-php${PHP_VERSION}"
        else
            PHP_ENABLE_REPO=""
        fi
    yum -y ${PHP_ENABLE_REPO} install \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX} \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-fpm \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-devel \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-curl \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-exif \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-fileinfo \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-gd \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-hash \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-intl \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-imap \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-json \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-mbstring \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-mcrypt \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-mysqlnd \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-soap \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-xml \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-simplexml \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-xmlrpc \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-xsl \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-zip \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-zlib \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-session \
        ${PHP_PREFIX}${PHP_VERSION}${PHP_SUFFIX}-filter
    
    if [ "${WEB_SERVER}" == "nginx" ]
    then
        if [[ "${PHP_VERSION}" == "54" ]] || [[ "${PHP_VERSION}" == "55" ]]
        then
            REMI_DIR="/etc/opt/remi"
            [ ! -d ${REMI_DIR} ] && mkdir ${REMI_DIR}
            ln -s /opt/remi/php${PHP_VERSION}/root/etc ${REMI_DIR}/php${PHP_VERSION}
        fi
    fi
}

_install_php(){
    if [ ! -z "${GET_PHP_VERSION}" ]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Installing PHP..."
        sleep 1
        _detect_web_server
        CHECK_WEB_SERVER=$?
        if [ ${CHECK_WEB_SERVER} -eq 11 ]
        then
            WEB_SERVER="nginx"
        elif [ ${CHECK_WEB_SERVER} -eq 21 ]
        then
            WEB_SERVER="openlitespeed"
        else
            _show_log -d -g " [INFO]" -w " Can not detect web server is running!"
            echo ""
            echo "Do you want to install php for nginx or lsphp for openlitespeed?"
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
            _show_log -d -g " [INFO]" -w " You choose install PHP for ${WEB_SERVER}"
        fi
        if [ "${WEB_SERVER}" == "nginx" ]
        then
            PHP_PREFIX="php"
            PHP_SUFFIX="-php"
            yum -y install centos-release-scl-rh
            yum -y --enablerepo=centos-sclo-rh-testing install devtoolset-6-gcc-c++
            rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-${OS_VER}.rpm
        else
            PHP_PREFIX="lsphp"
            PHP_SUFFIX=""
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OS_VER}.noarch.rpm
        fi

        if [ "${GET_PHP_VERSION}" == "all" ]
        then
            for i_INSTALL_PHP in $(echo ${List_PHP[*]} | sed 's/all//')
            do
                PHP_VERSION_REMI=`echo ${i_INSTALL_PHP} | sed 's/\.//'`
                _install_php_single "${PHP_VERSION_REMI}"           
                echo ""
                _check_installed_service "php${PHP_VERSION_REMI}" "new"
            done
        else
            PHP_VERSION_REMI=`echo ${GET_PHP_VERSION} | sed 's/\.//'`
            _install_php_single "${PHP_VERSION_REMI}"
            echo ""
            _check_installed_service "php${PHP_VERSION_REMI}" "new"
        fi
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
        elif [ "${GET_WEB_SERVER}" == "openlitespeed" ]
        then
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OS_VER}.noarch.rpm
            yum -y install openlitespeed
            if [ ! -f /usr/local/bin/openlitespeed ]
            then
                ln -s /usr/local/lsws/bin/openlitespeed /usr/local/bin/openlitespeed
            fi
        fi
        echo ""
        _check_installed_service "${GET_WEB_SERVER}" "new"
    fi
}

##Install MariaDB
_install_mariadb(){    
    if [ ! -z "${GET_SQL_SERVER}" ]
    then
        _check_service "mysql"
        if [ $? -eq 0 ]
        then
            echo ""
            _show_log -d -g " [INFO]" -w " MySQL installed. Do not install new!"
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
baseurl = http://yum.mariadb.org/${GET_SQL_SERVER}/centos${OS_VER}-${OS_ARCH1}
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
        _show_log -d -g " [INFO]" -w " Detecting PHP version installed..."
        CHECK_PHP_INSTALLED=`ls -1 /etc/opt/remi | wc -l`
        if [ ${CHECK_PHP_INSTALLED} -eq 0 ]
        then
            _show_log -d -r " [FAIL]" -w " Can not detect PHP version! Exit"
            exit 1
        fi
        for i_INSTALL_PHPMYADMIN in $(ls -1 /etc/opt/remi | sed 's/php//')
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
        _show_log -d -g " [INFO]" -w " Highest PHP version is ${PHP_VERSION_PMD}. We will install phpMyAdmin ${PMD_VERSION}."
        wget -O ${HOME}/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PMD_VERSION}/phpMyAdmin-${PMD_VERSION}-all-languages.tar.gz
        tar -xf ${HOME}/phpmyadmin.tar.gz
        rm -f ${HOME}/phpmyadmin.tar.gz
        mv ${HOME}/phpMyAdmin-${PMD_VERSION}-all-languages ${HOME}/phpmyadmin
        mv ${HOME}/phpmyadmin/ ${DEFAULT_DIR_WEB}
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
    cd /root
    wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
    bash imav-deploy.sh
}

# Config services
##Config PHP
_config_php_single(){
    PHP_VERSION_REMI=`echo $1 | sed 's/\.//'`
    echo ""
    _show_log -d -g " [INFO]" -w " Configing PHP ${PHP_VERSION_REMI}..."
    mv ${REMI_DIR}/php${PHP_VERSION_REMI}/php.ini ${REMI_DIR}/php${PHP_VERSION_REMI}/php.ini.orig
    cat ${REMI_DIR}/php${PHP_VERSION_REMI}/php.ini.orig | sed \
       "s/memory_limit = 128M/memory_limit = 256M/; \
        s/upload_max_filesize = 2M/upload_max_filesize = 200M/; \
        s/post_max_size = 8M/post_max_size = 200M/; \
        s/max_execution_time = 30/max_execution_time = 300/; \
        s/max_input_time = 60/max_input_time = 300/; \
        s/; max_input_vars = 1000/max_input_vars = 10000/" > ${REMI_DIR}/php${PHP_VERSION_REMI}/php.ini
}

_config_php(){
    if [ ! -z "${GET_PHP_VERSION}" ]
        then
        echo ""
        _show_log -d -g " [INFO]" -w " Configing PHP..."
        sleep 1
        if [ "${GET_PHP_VERSION}" == "all" ]
        then
            for i in $(echo ${List_PHP[*]} | sed 's/all//')
            do
                PHP_VERSION_REMI=`echo ${i} | sed 's/\.//'`
                _config_php_single "${PHP_VERSION_REMI}"
                _show_log -d -g " [INFO]" -w " Config PHP $i sucessful!"
            done
        else
            PHP_VERSION_REMI=`echo ${GET_PHP_VERSION} | sed 's/\.//'`
            _config_php_single "${PHP_VERSION_REMI}"
            _show_log -d -g " [INFO]" -w " Config PHP ${PHP_VERSION_REMI} sucessful!"
        fi
    fi
}

##Config WEB server
###Config Nginx
_config_nginx(){
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        echo ""
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
}

_config_openlitespeed(){
    :
}

##Config phpmyadmin
_config_phpmyadmin(){
    echo ""
    _show_log -d -g " [INFO]" -w " Configing phpmyadmin..."
    sleep 1
    PHP_VERSION_REMI=`echo ${PHP_VERSION_PMD} | sed 's/\.//'`
    FPM_DIR="${REMI_DIR}/php${PHP_VERSION_REMI}/php-fpm.d"
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

    _detect_web_server
    CHECK_WEB_SERVER=$?
    if [[ ${CHECK_WEB_SERVER} -eq 10 ]] || [[ ${CHECK_WEB_SERVER} -eq 11 ]]
    then
        chown -R nginx.nginx ${DEFAULT_DIR_WEB}/phpmyadmin
    elif [[ ${CHECK_WEB_SERVER} -eq 20 ]] || [[ ${CHECK_WEB_SERVER} -eq 21 ]]
    then
        chown -R openlitespeed.openlitespeed ${DEFAULT_DIR_WEB}/phpmyadmin
    else
        _show_log -d -g " [INFO]" -w " Can not detect web server, do not chown phpmyadmin directory!"
    fi
   
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
listen = /var/run/phpmyadmin.php${PHP_VERSION_REMI}.sock
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
            fastcgi_pass        unix:/var/run/phpmyadmin.php${PHP_VERSION_REMI}.sock;
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

    _show_log -d -g " [INFO]" -w " Config phpmyadmin sucessful!"
}

## Config MySQL
_config_mariadb(){
    if [[ ! -z "${GET_SQL_SERVER}" ]] && [[ "${NOT_CONFIG_MYSQL}" != "1" ]]
    then
        echo ""
        _show_log -d -g " [INFO]" -w " Configing SQL..."
        sleep 1
        CHECK_MARIADB=`mysql -V | grep MariaDB | wc -l`
        if [ ${CHECK_MARIADB} = 1 ]
        then
            MYSQL="mysql"
        else
            MYSQL="mysqld"
        fi
        service ${MYSQL} restart
        SQLPASS=`date +%s | sha256sum | base64 | head -c 12`
        /usr/bin/mysql_secure_installation << EOF

y
${SQLPASS}
${SQLPASS}
y
y
y
y
EOF

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

        _show_log -d -g " [INFO]" -w " Config SQL sucessful!"
    fi
}

# Config FTP
_config_ftp(){
    :
}
_config_csf(){
    echo ""
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

# Config webserver
_config_web(){
    if [ ! -z "${GET_WEB_SERVER}" ]
    then
        _config_${GET_WEB_SERVER}
    fi
}

# Restart service
restart_services(){
    if [ -f /bin/systemctl ]
    then
        systemctl restart ${1}
    else
        service ${1} restart
    fi
}

# Start service when boot
start_on_boot(){
    if [ -f /bin/systemctl ]
    then
        systemctl enable ${1}
    else
        chkconfig ${1} on
    fi
}

check_exist(){
   if [ ${1} -eq 1 ]
    then
        echo -e "${LANG_CHECK_EXIST1}"
    else
        echo -e "${LANG_CHECK_EXIST2}"
    fi
}

# Show install time and say good bye
end_time(){
    INSTALL_TIME=$((${END_TIME} - ${BEGIN_TIME}))
    HOUR=$((${INSTALL_TIME}/3600))
    MINUTE=$((${INSTALL_TIME}%3600/60))
    SECOND=$((${INSTALL_TIME}%60))
    if [ ${HOUR} -lt 10 ]
    then
        HOUR="0${HOUR}"
    fi
    if  [ ${MINUTE} -lt 10 ]
    then
        MINUTE="0${MINUTE}"
    fi
    if  [ ${SECOND} -lt 10 ]
    then
        SECOND="0${SECOND}"
    fi
    echo -e "${LANG_END_TIME1}${GREEN}${RIGHT_NOW}${REMOVE}"
    echo -e "${LANG_END_TIME2}${GREEN}${RIGHT_NOW2}${REMOVE}"
    echo -e "${LANG_END_TIME3}${GREEN}${HOUR}:${MINUTE}:${SECOND}${REMOVE}"
}

# Check services after install
_check_service(){
    case $1 in
        -i) command -v $2 | wc -l ;;
        -r) pidof $2 | wc -l ;;
    esac
}

# Show information to screen
show_info(){
    echo " ---"
    echo "${LANG_SHOW_INFO1}"
    if [[ "${OPTION}" == "mysql" ]] || [[ "${OPTION}" == "all" ]]
    then
        if [[ "${MYSQL_INST}" != "no" ]] && [[ "${AUTO_CONFIG}" != "yes" ]]
        then
            echo "${LANG_SHOW_INFO2}"
        elif [[ "${MYSQL_INST}" != "no" ]] && [[ "${AUTO_CONFIG}" == "yes" ]]
        then
            echo "${LANG_SHOW_INFO3}"
            echo "${LANG_SHOW_INFO4}"
            echo " http://${IPADDRESS}/phpmyadmin"
            echo "${LANG_SHOW_INFO5}"
            echo "${LANG_SHOW_INFO6} ${SQLPASS}"
        fi
    fi
    echo ""
    echo "${LANG_SHOW_INFO7}"
    echo -e "${LANG_SHOW_INFO8}"
}

# Download mce
download_mce(){
    if [ ${CHOOSE_LANG} -eq 1 ]
    then
        LANG="en"
    elif [ ${CHOOSE_LANG} -eq 2 ]
    then
        LANG="vi"
    fi
    if [[ "${OPTION}" == "all" ]] && [[ "${WEB}" == "nginx" ]]
    then
        echo -e "${LANG_DOWNLOAD_MCE1}"
        false
        while [ $? -eq 1 ]
        do
            read -p "${LANG_DOWNLOAD_MCE2}" CHOICE
            if [[ $CHOICE == Yes ]] || [[ $CHOICE == No ]]
            then
                true
            else
                echo -e "${RED}${LANG_DOWNLOAD_MCE7}${REMOVE}"
                false
            fi
        done
        if [ "${CHOICE}" == "Yes" ]
        then
            echo -e "${GREEN}${LANG_DOWNLOAD_MCE3}${REMOVE}"
            sleep 2
            curl -o ${DIR}/mce_create ${GITHUB_LINK}/lemp/mce_create
            sh ${DIR}/mce_create ${LANG}
            rm -f ${DIR}/mce_create
            mv ${DIR}/build ${BASH_DIR}/build
            mv ${DIR}/options.conf ${BASH_DIR}/options.conf
            echo ""
            echo -e "${LANG_DOWNLOAD_MCE4}"
        fi
    fi
    echo -e "${LANG_DOWNLOAD_MCE5}"
    echo -e "${LANG_DOWNLOAD_MCE6}"
    for i in 5 4 3 2 1
    do
        printf "$i "
        sleep 1
    done
    echo "REBOOT!"
    init 6
}

# Choose languages
choose_languague(){
    false
    while [ $? -eq 1 ]
    do
        List_CHOOSE_LANG=(1 2)
        read -p " Your choice( Lựa chọn của bạn): " CHOOSE_LANG
        _check_value_in_list "${CHOOSE_LANG}" "${List_CHOOSE_LANG[*]}"
        if [ $? -eq 1 ]
        then
            echo " Wrong option. Please choose 1 or 2!"
            echo "(Lựa chọn không phù hợp. Vui lòng chọn 1 hoặc 2!)"
            choose_languague
        fi
    done
}

# Main install
_main_install(){
    _install_ftp
    _install_php
    _install_mariadb
    _install_web
    if [ ! -z "${EXTRA_SERVICE}" ]
    then
        for i_EXTRA_SERVICE in $(cat /tmp/extra_service_min.txt)
        do
            _install_${i_EXTRA_SERVICE}
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
}

# Show help
_show_help(){
    echo "Usage: sh ${SCRIPT_NAME} [options...]"
    echo "Options:"
    echo "    -a               Install all services."
    echo "    -e [extra]       Install extra services. Can use multiple -e options."
    echo "        extra:       $(echo ${List_EXTRA[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -f [ftp-server]  Choose ftp server will be installed."
    echo "        ftp-server:  $(echo ${List_FTP[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -p [php-version] Choose php version will be installed."
    echo "        php-version: $(echo ${List_PHP[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -s [sql-server]  Choose sql server will be installed."
    echo "        sql-server:  $(echo ${List_SQL[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -w [web-server]  Choose web server will be installed."
    echo "        web-server:  $(echo ${List_WEB[*]} | sed 's/ /|/g')"
    echo ""
    echo "    -h               Show help"
    echo "    -v               Show version"    
    echo "    -x               Debug mode"
    echo ""
    echo "Example:"
    echo "    sh ${SCRIPT_NAME} -a"
    echo "    sh ${SCRIPT_NAME} -p 7.3 -w nginx -s 10.4 -f proftpd -e phpmyadmin -e csf"
}

rm -f /tmp/config_service.txt /tmp/config_service_min.txt /tmp/extra_service.txt /tmp/extra_service_min.txt /tmp/show_info.txt
while getopts 'e:f:p:s:w:ahxv' OPTION
do
    case ${OPTION} in
        a) INSTALL_ALL=1 ;;
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
        p) GET_PHP_VERSION=${OPTARG} ;;
        s) GET_SQL_SERVER=${OPTARG} ;;
        w) GET_WEB_SERVER=${OPTARG} ;;
        h) _show_help; exit 0 ;;
        v) head -n 5 ${SCRIPT_NAME} | grep "^# Version:" | awk '{print $3}' ; exit 0 ;;
        x) set -x ;;
        *) _show_help; exit 1 ;;
    esac
done
_show_log -w "---"
_create_dir
#_multi_lang
_check_control_panel
_check_info
#_pre_install
#_sync_time
#_start_time
_main_install
