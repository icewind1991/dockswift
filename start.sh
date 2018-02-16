#!/bin/bash

sudo echo "127.0.0.1 mariadb" >> /etc/hosts
sudo echo "127.0.0.1 swift" >> /etc/hosts

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
