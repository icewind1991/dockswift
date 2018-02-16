dockswift
=========

### Dockerfile ###

One dockerfile working for keystone/swift/horizon and compatible with Object Storage Clients like Cyberduck.
To run the container, provide your ip address as an environment variable (ex : localhost or boot2docker ip)

Here is a sample command to run :

    docker run -P -p 80:80 -p 8080:8080 -p 5000:5000 -p 35357:35357 -p 8000:8000 -d -e IPADDRESS=192.168.59.103 --name swift icewind1991/dockswift

Temp url settings :

    docker exec -it swift swift post -m "Temp-URL-Key:temp_url_key" -V 2 --os-auth-url='http://localhost:5000/v2.0' --os-username='swift' --os-password='swift' --os-tenant-name='service'

#### Ports ####

80:80 - To connect to the horizon dashboard

5000:5000 - To connect to keystone using external clients

35357 - To connect to keystone using admin url

8080:8080 - To access to Object Storage after Keystone authentication

8000:8000 - To connect to Swiftbrowser

#### Volumes ####

/etc/mysql - configurations for mysql.

/var/lib/mysql - The actual database. This will make the openstack database persistant between reboots.

/etc/keystone - Configuration for keystone.

/etc/openstack-dashboard - Configuration for django.

/srv - Volume for Swift Object Storage.

#### Environment Variables ####

IPADDRESS=localhost or IPADDRESS=192.168.59.103 (boot2docker ip) This sets the endpoint of Swift for Keystone. It allows the use of external Swift Clients using Keystone

#### Cyberduck ####

To access to your Storage through Cyberduck, you can download the preconfigured settings here :

   https://svn.cyberduck.io/trunk/profiles/Openstack%20Swift%20(HTTP).cyberduckprofile

Then configure :

     Server : (your ip address)
     Port : 5000
     Username : (tenant name):(user name)
     Password : (user password)

#### Swiftbrowser ####

To access to swiftbrowser, open "http://(your ip address):8000/" in your browser and use 'admin:admin' (Username) and 'openstack' (Password) to login (default ids)

#### Horizon ####

To access to Horizon, open "http://(your ip adress)/" in your browser and use 'admin' (Username) and 'openstack' (Password) to login (default ids)
