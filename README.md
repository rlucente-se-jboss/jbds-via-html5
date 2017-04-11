# Holy Guacamole!!
[Apache Guacamole](https://guacamole.incubator.apache.org/) is an
incubating Apache project that enables legacy X window applications
to be exposed via HTML5 and accessed via a browser.  This project
shows how that can be done using containers within OpenShift Container
Platform.

## Install Guacamole Components
First, create a guacamole project within the OpenShift Container
Platform.  This example uses the [Container Development Kit
(CDK)](https://developers.redhat.com/products/cdk/overview/), so
you'll need to adjust instructions for other installed platforms.

    oc login 10.1.2.2:8443 -u openshift-dev
    oc new-project guacamole

Create the guacamole mysql instance and then modify to use a
persistent volume.

   oc new-app mysql MYSQL_USER=guacamole MYSQL_PASSWORD=guacamole \
       MYSQL_DATABASE=guacamole
   oc volume dc/mysql --add --name=mysql-volume-1 -t pvc --claim-name=mysql-data \
       --claim-size=1G --overwrite

Use the guacamole docker image to create a database initialization
script.

    docker pull guacamole/guacamole
    docker pull guacamole/guacd
    docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql > initdb.sql

Wait for the mysql pod to fully start (may restart due to the dc
change above).  Get the list of running pods to determine the pod-id
for mysql.

    oc get pods

Identify the path to the mysql application.  To do that, type the
following:

    oc rsh mysql-<pod-id>
    echo $PATH | cut -d: -f1
    exit

Use the pod-id and the executable path from the above command to
initialize the database:

    oc rsh mysql-<pod id> <exec-path>/mysql -h 127.0.0.1 -P 3306 -u guacamole -pguacamole guacamole < initdb.sql

Now launch a pod for both guacamole and guacd.

    oc new-app guacamole/guacamole+guacamole/guacd \
        --name=holy \
        GUACD_HOSTNAME=127.0.0.1 \
        GUACD_PORT=4822 \
        MYSQL_HOSTNAME=mysql.guacamole.svc.cluster.local \
        MYSQL_PORT=3306 \
        MYSQL_DATABASE=guacamole \
        MYSQL_USER=guacamole \
        MYSQL_PASSWORD=guacamole

Expose the service to external users:

    oc expose service holy --port=8080 --path=/guacamole

## Configure Guacamole Users
When accessing the guacamole web site, the default username/password
is `guacadmin/guacadmin`.

blah blah blah add a new user with permissions to change password and create new connection

## Build the JBDS App

    cd    
    git clone https://github.com/rlucente-se-jboss/jbds-via-html5.git
    cd jbds-via-html5/resources
    python3 -m http.server

In separate terminal,

    cd ~/jbds-via-html5
    oc new-app . --name=jbds --strategy=docker
    oc start-build --from-dir=.


