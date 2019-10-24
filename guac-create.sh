#!/bin/bash

# Author: Lee Jae Seung
# Create: 19.10.25
# Site  : g0pher.kr

# isroot
if ! [ $(id -u) = 0 ]; then echo "You are not root"; exit 1 ; fi

# Colors
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NONE='\033[0m'

# Set container info
container-demon="guacamole-demon"
container-db="guacamole-database"
container-front="guacamole"
db-name="guacamole-db"
service-port=8080

# get password
read -p "Input root pw of DB : " rootpw
read -p "Input user id of DB : " userid
read -p "Input user pw of DB : " userpw

# Create guacamole demon container
echo -e "${BLUE}Create guacamole demon container${NONE}"
docker run -d --name ${container-demon} --restart=unless-stopped guacamole/guacd
if [ $? -ne 0 ]; then
    echo -e "${RED}Fail${NONE}"
    exit 1
else
    echo -e "${GREEN}OK${NONE}"
fi

# Create guacamole database container
echo -e "${BLUE}Create guacamole database container{NONE}"
docker run -d --name ${container-db} \
  --restart=unless-stopped \
  -e MYSQL_ROOT_PASSWORD='${rootpw}' \
  mariadb
if [ $? -ne 0 ]; then
    echo -e "${RED}Fail${NONE}"
    exit 1
else
    echo -e "${GREEN}OK${NONE}"
fi

# Initial setting of guacamole database container
echo -e "${BLUE}Initial setting of guacamole database container{NONE}"
docker run --rm guacamole/guacamole \
  /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
SQLUSER="
create database ${db-name};
create user '${userid}'@'%' idenfitied by '${userpw}';
grant select, insert, update, delete on ${db-name}.* to '${userid}'@'%';
FLUSH PRIVILEGES;"
echo SQLUSER >> ./initdb.sql
docker cp ./initdb.sql ${container-db}:/tmp/initdb.sql
docker exec -it guacamole-db "mysql -u root -p ${db-name} < /tmp/initdb.sql"
rm ./initdb.sql

# Create guacamole front container
echo -e "${BLUE}Create guacamole front container{NONE}"
docker run -d --name ${container-front} \
--link ${container-demon} \
--link ${container-db} \
--restart=unless-stopped \
-e GUACD_HOSTNAME=${container-demon} \
-e MYSQL_HOSTNAME=${container-db} \
-e MYSQL_DATABASE=${db-name} \
-e MYSQL_USER='${userid}' \
-e MYSQL_PASSWORD='${userpw}' \
-p ${service-port}:8080 guacamole/guacamole
if [ $? -ne 0 ]; then
    echo -e "${RED}Fail${NONE}"
    exit 1
else
    echo -e "${GREEN}OK! Connect server on 8080 port's /guacamole/.${NONE}"
fi
