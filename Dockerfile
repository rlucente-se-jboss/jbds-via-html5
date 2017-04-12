########################################################################
#                   JBoss Developer Studio via HTML5                   #
########################################################################

FROM fedora:25

MAINTAINER Rich Lucente <rlucente@redhat.com>

LABEL vendor="Red Hat"
LABEL version="0.1"
LABEL description="JBoss Developer Studio IDE"

ENV FILE_HOST 10.1.2.2
ENV HOME /home/jbdsuser
ENV JBDS_JAR devstudio-10.3.0.GA-installer-standalone.jar

# Add the needed packages for JBDS
RUN    dnf -y update \
    && dnf -y install \
           gettext \
           gtk2 \
           java-1.8.0-openjdk-devel \
           liberation-sans-fonts \
           webkitgtk \
           maven \
           nss_wrapper \
           openbox \
           tigervnc-server \
           wmctrl \
    && dnf -y clean all

# Set the openbox window manager configuration for all users
RUN    echo 'export DISPLAY=:1' >> /etc/xdg/openbox/environment \
    && echo "/usr/share/devstudio/devstudio -nosplash -data ${HOME}/workspace &" \
             >> /etc/xdg/openbox/autostart

# Install JBoss Developer Studio.  The needed files will be downloaded
# from the host where the docker build was initiated.  The IP address
# will need to be adjusted for where the docker build is being run.
# The reason for this is to not include the JBDS distribution in the
# docker layer since this image is going to be quite large.  If the
# docker ADD instruction is used the file becomes a permanent part
# of that layer, bloating the size of an already large image.
#
# The for loops scan the JBDS installation for native libraries and
# then remove any that are already present in the system libraries.
# Redundant libraries that varied by version resulted in JBDS
# crashes.
#
RUN    mkdir -p /tmp/resources \
    && cd /tmp/resources \
    && curl -L -O http://$FILE_HOST:8000/$JBDS_JAR \
    && curl -L -O http://$FILE_HOST:8000/InstallConfigRecord.xml \
    && java -jar $JBDS_JAR InstallConfigRecord.xml \
    && rm -fr /tmp/resources \
    && cd /usr/share/devstudio \
    && for ext in so chk; do \
         for jbdslib in `find . -name "*.$ext"`; do \
           jbdslib_basename=`basename $jbdslib`; \
           for syslibdir in /lib64 /usr/lib64; do \
             for dummy in `find $syslibdir -name $jbdslib_basename`; do \
               [ -f $jbdslib ] && rm -f $jbdslib; \
             done; \
           done; \
         done; \
       done

# This script starts and cleanly shuts down JBDS and the Xvnc server
ADD resources/start.sh /usr/local/bin/

# This file is used to create a temporary passwd file for use by
# the NSS wrapper so that the openbox window manager can launch
# correctly.  OCP will use a non-deterministic user id, so we have
# to provide a valid passwd entry for that UID for openbox
ADD resources/passwd.template /usr/local/share/

# Create the home directory and set permissions
RUN    mkdir -p ${HOME} \
    && chmod a+rwX ${HOME} \
    && chmod a+rx /usr/local/bin/start.sh \
    && chmod a+r /usr/local/share/passwd.template

EXPOSE 5901

USER 1000

CMD /usr/local/bin/start.sh

# No volume support yet, so everything in /home/jbdsuser is ephemeral.
# Eventually this can be a mounted persistent volume so each user can
# have a persistent maven repository, workspace, etc.
