#!/bin/bash

function wait_mariadb_start() {
  sleep 2
  while [ `mysqlcheck mysql -u "root" "-popenstack" |wc -l` -lt 2 ]
  do
    sleep 2
  done
  sleep 2
}

function wait_mariadb_stop() {
  sleep 2
  while [ `mysqlcheck mysql |wc -l` -gt 2 ]
  do
    sleep 2
  done
  sleep 2
}

sudo echo "127.0.0.1 mariadb" >> /etc/hosts

if [ ! -d "/var/lib/mysql/mysql" ]; then
  /usr/bin/mysql_install_db
  chown mysql: /var/lib/mysql

fi

if [ ! -f "/etc/mysql/my.cnf" ]; then
  cp -R /root/mariadb/etc/mysql/* /etc/mysql

fi

if [ ! -f "/usr/local/etc/initialize_db.sql" ]; then
  cp /root/initialize_db.sql /usr/local/etc/

fi

echo "INITIALIZE flag has been set.  Setting up the database for OpenStack"
echo
echo "Starting MariaDB (skip-grant-tables)..."
/usr/bin/mysqld_safe --skip-grant-tables &
wait_mariadb_start
/usr/bin/mysql -u root -e "use mysql; update user set password=PASSWORD('openstack') where User='root';"
echo "Updated root password"
sleep 2
echo "Flushing and stopping the database..."
/usr/bin/mysql -u root -e "flush privileges;"
sleep 2
killall mysqld
wait_mariadb_stop
echo "Starting up MariaDB to add OpenStack databases..."
/usr/bin/mysqld_safe &
wait_mariadb_start
echo "Adding OpenStack databases and users..."
/usr/bin/mysql -u "root" "-popenstack" < /usr/local/etc/initialize_db.sql
sleep 2
echo "Adding phpMyAdmin schema..."
/usr/bin/mysql -u "root" "-popenstack" < /usr/local/etc/create_tables.sql
sleep 2
echo "Stopping the database..."
sleep 2
killall mysqld
wait_mariadb_stop
echo "INITILIAZATION IS COMPLETE"

sleep 5

service apache2 start
service mysql restart

sleep 10

sudo echo "127.0.0.1 keystone" >> /etc/hosts

if [ ! -f "/etc/keystone/keystone.conf" ]; then
  echo "Adding default config files to /etc/keystone"
  cp -R /root/keystone/* /etc/keystone
fi

KEY_PASS=`cat /etc/keystone/keystone.conf |grep ^connection\ |awk -F'@' '{print $1}'|awk -F':' '{print $3}'`
KEY_HOST=`cat /etc/keystone/keystone.conf |grep ^connection\ |awk -F'@' '{print $2}'|awk -F'/' '{print $1}'`

RESULT=$(mysql -N -s -u keystone -p"$KEY_PASS" -h "$KEY_HOST" -e "select count(*) from information_schema.tables whe\
re table_schema='keystone' and table_name='migrate_version';")
EXIT=$?

if [ "$EXIT" -eq "1" ]; then
    echo "MySQL Error.  Please fix"
    exit
elif [ "$RESULT" -eq "1" ]; then
    echo "The glance database has already been configured"
    echo "INITILIAZATION IS COMPLETE"
else
    echo "The keystone database is missing the schema, initializing..."
    /bin/sh -c "keystone-manage db_sync" keystone
fi


/usr/bin/keystone-all &
sleep 2

if [ $(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list |grep admin |wc -\
l) -ne 1 ]; then
    echo "Didn't find the admin user, adding the admin user/tenant/role..."
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-create --name admin --d\
escription "Admin Tenant"
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-create --name service -\
-description "Service Tenant"
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-create --name admin --pas\
s openstack --email admin@localhost
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 role-create --name admin
#    echo "tenant list"
#    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-list
#    echo "user list"
#    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list
#    echo "role list"
#    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 role-list
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-role-add --tenant-id=$(ke\
ystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-list | awk '/ admin / {print \
$2}') --user-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list | awk \
'/ admin / {print $2}') --role-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d8\
4 role-list | awk '/ admin / {print $2}')
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 role-create --name _member_
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-role-add --tenant-id=$(ke\
ystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-list | awk '/ admin / {print \
$2}') --user-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list | awk \
'/ admin / {print $2}') --role-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d8\
4 role-list | awk '/ _member_ / {print $2}')
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 service-create --name keystone\
 --type identity --description "OpenStack Identity"

    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 endpoint-create \
      --service-id $(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 service-list \
| awk '/ identity / {print $2}') \
      --publicurl http://keystone:5000/v2.0 \
      --internalurl http://keystone:5000/v2.0 \
      --adminurl http://keystone:35357/v2.0 \
      --region regionOne

      echo "INITILIAZATION IS COMPLETE"
fi

sudo echo "127.0.0.1 swift" >> /etc/hosts

SWIFT_PART_POWER=${SWIFT_PART_POWER:-7}
SWIFT_PART_HOURS=${SWIFT_PART_HOURS:-1}
SWIFT_REPLICAS=${SWIFT_REPLICAS:-1}

if [ -e /srv/account.builder ]; then
        echo "Ring files already exist in /srv, copying them to /etc/swift..."
        cp /srv/*.builder /etc/swift/
        cp /srv/*.gz /etc/swift/
fi

chown -R swift:swift /srv

if [ ! -e /etc/swift/account.builder ]; then

        cd /etc/swift

        # 2^& = 128 we are assuming just one drive
        # 1 replica only

        echo "No existing ring files, creating them..."

        swift-ring-builder object.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
        swift-ring-builder object.builder add r1z1-127.0.0.1:6010/sdb1 1
        swift-ring-builder object.builder rebalance
        swift-ring-builder container.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
        swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdb1 1
        swift-ring-builder container.builder rebalance
        swift-ring-builder account.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
        swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdb1 1
        swift-ring-builder account.builder rebalance

        # Back these up for later use
        echo "Copying ring files to /srv to save them if it's a docker volume..."
        cp *.gz /srv
        cp *.builder /srv

fi

if [ ! -z "${SWIFT_STORAGE_URL_SCHEME}" ]; then
        echo "Setting default_storage_scheme to https in proxy-server.conf..."
        sed -i -e "s/storage_url_scheme = default/storage_url_scheme = https/g" /etc/swift/proxy-server.conf
        grep "storage_url_scheme" /etc/swift/proxy-server.conf
fi

#if [ ! -z "${SWIFT_SET_PASSWORDS}" ]; then
#        echo "Setting passwords in /etc/swift/proxy-server.conf"
#        PASS=`pwgen 12 1`
#        sed -i -e "s/user_admin_admin = admin .admin .reseller_admin/user_admin_admin = $PASS .admin .reseller_admin\
#/g" /etc/swift/proxy-server.conf
#        sed -i -e "s/user_test_tester = testing .admin/user_test_tester = $PASS .admin/g" /etc/swift/proxy-server.co\
#nf
#        sed -i -e "s/user_test2_tester2 = testing2 .admin/user_test2_tester2 = $PASS .admin/g" /etc/swift/proxy-serv\
#er.conf
#        sed -i -e "s/user_test_tester3 = testing3/user_test_tester3 = $PASS/g" /etc/swift/proxy-server.conf
#        grep "user_test" /etc/swift/proxy-server.conf
#fi

echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

SWIFT_ENDPOINT="dockswift"

if [ $(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list |grep swift |wc -\
l) -ne 1 ]; then
    echo "Didn't find the swift user, adding the swift user/tenant/role..."
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-create --name=swift --pas\
s=swift --tenant-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 tenant-list \
| awk '/ service / {print $2}')
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-role-add --user-id=$(keys\
tone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 user-list | awk '/ swift / {print $2}'\
) --role-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 role-list | awk '/ a\
dmin / {print $2}') --tenant-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 \
tenant-list | awk '/ service / {print $2}')
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 service-create --name=swift --\
type=object-store --description="OpenStack Object Storage"
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 endpoint-create --region regio\
nOne --service-id=$(keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 service-list |\
 awk '/ object-store / {print $2}') --publicurl="http://$SWIFT_ENDPOINT:8080/v1/AUTH_\$(tenant_id)s" --internalurl="http://$SWIFT_ENDPOINT:8080/v1/AUTH_\$(tenant_id)s" --adminurl="http://$SWIFT_ENDPOINT:8080"
    keystone --os-endpoint=http://keystone:35357/v2.0 --os-token=74d52ad7f4d039e55d84 role-create --name SwiftOperat\
or

fi

service apache2 stop
service mysql stop
killall keystone-all
