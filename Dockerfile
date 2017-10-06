FROM gyaworski/alpine-linux-openjdk-hardened:alpine-3.6-openjdk-8.131.11-r2-hardened-1.0

ENV CATALINA_HOME /home/tomcat
ENV CATALINA_OPTS -Dorg.apache.catalina.connector.RECYCLE_FACADES=true:$CATALINA_OPTS
ENV PATH $PATH:$CATALINA_HOME/bin
ENV sslCertCommonName=xyz
ENV tempTomcatNativeDir=/tmp/tomcat-native
ENV tomcatMajorVersion=8
ENV tomcatMinorVersion=5
ENV tomcatPatchVersion=20
ENV tomcatVersion=${tomcatMajorVersion}.${tomcatMinorVersion}.${tomcatPatchVersion}
ENV tomcatFilename=apache-tomcat-${tomcatVersion}.tar.gz
ENV tomcatDownloadUrl=http://archive.apache.org/dist/tomcat/tomcat-${tomcatMajorVersion}/v${tomcatVersion}/bin/${tomcatFilename}
ENV tomcatNativeLibDir=$CATALINA_HOME/lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${tomcatNativeLibDir}

# since image is hardened, we don't have APK
# run it from a static binary
ADD apk-tools-static-2.7.2-r0-x86_64.apk /apk-tools-static-2.7.2-r0-x86_64.apk

# install wget and other stuff needed to compile tomcat native
RUN set -x \
    && /apk-tools-static-2.7.2-r0-x86_64.apk/sbin/apk.static \
                    -X http://dl-cdn.alpinelinux.org/alpine/v3.6/community \
                    -X http://dl-cdn.alpinelinux.org/alpine/v3.6/main  \
                    -U \
                    add \
                    --allow-untrusted  \
                    --initdb  \
                    --progress \
                    --no-cache \
                    --virtual .native-build-deps \
                    wget \
                    apr-dev \
            		coreutils \
            		dpkg-dev dpkg \
            		gcc \
            		libc-dev \
            		make \
            		openssl \
            		openssl-dev \
            		openjdk8=8.131.11-r2 \
# do some pre-setup for Tomcat here ...
    && mkdir -p "$CATALINA_HOME" "$CATALINA_HOME"/logs "$CATALINA_HOME"/ssl ${tempTomcatNativeDir} \
    && addgroup tomcat \
    && adduser -h $CATALINA_HOME -s /bin/sh -G tomcat -D -g "dockerfile-created-tomcat-user" tomcat \
    && chown tomcat:tomcat $CATALINA_HOME "$CATALINA_HOME"/logs "$CATALINA_HOME"/ssl ${tempTomcatNativeDir}                   

WORKDIR $CATALINA_HOME

USER tomcat

RUN set -x \
    && wget "${tomcatDownloadUrl}" \
    && tar -xzf ${tomcatFilename} --strip-components=1 \
    && tar -xzf bin/tomcat-native.tar.gz -C ${tempTomcatNativeDir} --strip-components=1

USER root

ADD server.xml $CATALINA_HOME/conf
ADD web.xml $CATALINA_HOME/conf
ADD logging.properties $CATALINA_HOME/conf

RUN set -x \
# compile & install Tomcat Native APR libs
    && ( \
       cd ${tempTomcatNativeDir}/native \
       && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
       && ./configure \
            --build="$gnuArch" \
            --prefix="$CATALINA_HOME" \
            --with-apr="$(which apr-1-config)" \
            --with-java-home=/usr/lib/jvm/java-1.8-openjdk \
            --with-ssl=yes \
       && make -j "$(nproc)" \
       && make install \
    ) \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive "${tomcatNativeLibDir}" \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && /apk-tools-static-2.7.2-r0-x86_64.apk/sbin/apk.static add --virtual .tomcat-native-rundeps $runDeps \
# enable SSL
	&& openssl req -newkey rsa:2048 -x509 -keyout $CATALINA_HOME/ssl/server.pem -out $CATALINA_HOME/ssl/server.crt -nodes -subj '/CN=${sslCertCommonName}' \
# harden Tomcat: https://www.owasp.org/index.php/Securing_tomcat	
    && chown tomcat:tomcat $CATALINA_HOME/conf/server.xml \
    				       $CATALINA_HOME/conf/web.xml \
    				       $CATALINA_HOME/conf/logging.properties \
    && chmod 400 $CATALINA_HOME/LICENSE $CATALINA_HOME/NOTICE \
    && chmod -R 400 $CATALINA_HOME/conf/* \
    && chmod 500 $CATALINA_HOME/bin $CATALINA_HOME/conf $CATALINA_HOME/ssl $CATALINA_HOME/lib \
    && chmod 300 $CATALINA_HOME/logs \
    && chmod -w $CATALINA_HOME \
    && chmod -w -R $CATALINA_HOME/bin/* $CATALINA_HOME/include/* $CATALINA_HOME/lib/* \
                   $CATALINA_HOME/ssl/* \
    && rm -rf $CATALINA_HOME/webapps/* \
# clean up ...
    && rm -rf ${tempTomcatNativeDir} \
    && rm -f ${tomcatFilename} \
    && rm -f $CATALINA_HOME/RELEASE-NOTES \
    && rm -f $CATALINA_HOME/RUNNING.txt \
    && rm -f bin/tomcat-native.tar.gz \
# clean up after using APK ...
#    && /apk-tools-static-2.7.2-r0-x86_64.apk/sbin/apk.static del --purge .native-build-deps

USER tomcat
EXPOSE 8443
CMD ["catalina.sh", "run"]