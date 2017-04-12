# Holy Guacamole!!
[Apache Guacamole](https://guacamole.incubator.apache.org/) is an
incubating Apache project that enables X window applications to be
exposed via HTML5 and accessed via a browser.  This project shows
how that can be done using containers within OpenShift Container
Platform.  Specifically, JBoss Developer Studio, the eclipse-based
IDE for the JBoss middleware portfolio, is hosted within a container
and accessed via a web browser.

## Install Guacamole Components
First, create a project for guacamole within the OpenShift Container
Platform.  This example uses the [Container Development Kit
(CDK)](https://developers.redhat.com/products/cdk/overview/), so
you'll need to adjust instructions for other installed platforms.

    oc login 10.1.2.2:8443 -u openshift-dev
    oc new-project guacamole

Create the guacamole mysql instance and then modify it to use a
persistent volume.  This mysql database will provide persistence
for users and connection parameters within guacamole.

    oc new-app mysql MYSQL_USER=guacamole MYSQL_PASSWORD=guacamole \
        MYSQL_DATABASE=guacamole
    oc volume dc/mysql --add --name=mysql-volume-1 -t pvc \
        --claim-name=mysql-data --claim-size=1G --overwrite

Run the guacamole image to create a database initialization script
for guacamole.  We use the `oc run` command to run the image with
an alternate command.

    oc run guacamole --image=guacamole/guacamole --restart=Never \
        --command -- /opt/guacamole/bin/initdb.sh --mysql 

This will run the given command within a pod named `guacamole`.
When the command completes, the logs will contain the standard
output.  Put this output into a sql file.

    oc logs guacamole > initdb.sql
    oc delete pod guacamole

At this point, the mysql pod should have fully started, but it may
have restart due to the deployment configuration change to add the
persistent volume claim).  Get the list of running pods to determine
the pod-id for mysql.

    oc get pods

Identify the path to the mysql application.  To do that, type the
following:

    oc rsh mysql-<pod-id>
    echo $PATH | cut -d: -f1
    exit

Use the pod-id and the executable path from the above command to
initialize the database:

    oc rsh mysql-<pod id> <exec-path>/mysql -h 127.0.0.1 -P 3306 \
        -u guacamole -pguacamole guacamole < initdb.sql

Now that the database is prepped, create an application where both
guacamole and guacd are in a single pod.  The additional parameters
will connect it to its database.

    oc new-app guacamole/guacamole+guacamole/guacd \
        --name=holy \
        GUACD_HOSTNAME=127.0.0.1 \
        GUACD_PORT=4822 \
        MYSQL_HOSTNAME=mysql.guacamole.svc.cluster.local \
        MYSQL_PORT=3306 \
        MYSQL_DATABASE=guacamole \
        MYSQL_USER=guacamole \
        MYSQL_PASSWORD=guacamole

Create a route for the guacamole application.

    oc expose service holy --port=8080 --path=/guacamole

## Configure Guacamole Users
Use your browser to access the guacamole application.  On the CDK,
the URL is:

    holy-guacamole.rhel-cdk.10.1.2.2.xip.io

Make sure that the URL is appropriate for your environment.  The
default username and password is `guacadmin/guacadmin`.  Once logged
in, in the upper right hand corner select "guacadmin -> Settings".

Select the "Users" tab and then click the "New User" button.  Set
the username and password to whatever you desire.  As an admin, you
can create multiple user accounts that can then connect to their
own instances of JBoss Developer Studio.  Also, make sure to assign
the permissions "Create new connections" and "Change own password".
Click "Save" to add the user.

## Build the JBDS App
Build and deploy the JBoss Developer Studio container image.  To
limit the size of the container image, some files are downloaded
at build time.

Get the appropriate URL for the JBoss Developer Studio installer.
This has been tested against version 10.3.0.GA of the installer.
To get the URL, browse to:

    https://developers.redhat.com/products/devstudio/download/

Click the `Stand-Alone` download link for version 10.3.0.GA.  The
web site will prompt you to log in.  Use your credentials (or
register if you haven't yet done so) and then cancel the download
when it starts.  Within the "Thank you..." box on the page, copy
the link location for `Direct Link`.

Build and deploy the application.  Make sure to paste the `Direct
Link` URL in the command below.

    oc new-app https://github.com/rlucente-se-jboss/jbds-via-html5#fed25 \
        --name=jbds --strategy=docker
    oc cancel-build jbds-1
    oc start-build jbds \
        -e JBDS_JAR=devstudio-10.3.0.GA-installer-standalone.jar \
        -e INSTALLER_URL=<direct-link-URL>

This will take a little time to build the container image.

## Access the JBDS Container via a Browser
Once the jbds application has been deployed, the JBoss Developer
Studio application can be accessed via a browser.  Use your browser
to access the guacamole application.  On the CDK, the URL is:

    holy-guacamole.rhel-cdk.10.1.2.2.xip.io

Make sure that the URL is appropriate for your environment.  Make
sure to use the username/password that was created above within
guacamole.  Once logged in, in the upper right hand corner select
"guacadmin -> Settings".
