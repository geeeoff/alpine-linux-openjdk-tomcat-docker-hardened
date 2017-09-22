ARG alpineLinuxVersion=3.6

FROM alpine:${alpineLinuxVersion} AS alpine-linux

ENV CATALINA_HOME /usr/local/tomcat
ENV CATALINA_OPTS -Dorg.apache.catalina.connector.RECYCLE_FACADES=true:$CATALINA_OPTS
ENV PATH $PATH:$CATALINA_HOME/bin

ARG sslCertCommonName=xyz
ARG tempTomcatNativeDir=/tmp/tomcat-native

ARG alpineLinuxVersion
ARG alpineOpenJdkMajorVersion=8
ENV JAVA_HOME /usr/lib/jvm/java-1.${alpineOpenJdkMajorVersion}-openjdk/jre
ENV PATH $PATH:$JAVA_HOME/bin

ARG alpineOpenJdkMinorVersion=131
ARG alpineOpenJdkPatchVersion=11-r2
ARG alpineOpenJdkVersion=${alpineOpenJdkMajorVersion}.${alpineOpenJdkMinorVersion}.${alpineOpenJdkPatchVersion}

ARG tomcatMajorVersion=8
ARG tomcatMinorVersion=5
ARG tomcatPatchVersion=20
ARG tomcatVersion=${tomcatMajorVersion}.${tomcatMinorVersion}.${tomcatPatchVersion}
ARG tomcatFilename=apache-tomcat-${tomcatVersion}.tar.gz
ARG tomcatDownloadUrl=http://apache.org/dist/tomcat/tomcat-${tomcatMajorVersion}/v${tomcatVersion}/bin/${tomcatFilename}
ARG tomcatNativeLibDir=$CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${tomcatNativeLibDir}

WORKDIR $CATALINA_HOME

# install JRE
RUN set -x \
    && apk add \
        --no-cache \
        --progress \
            openjdk${alpineOpenJdkMajorVersion}-jre="${alpineOpenJdkVersion}" \
#            openssl \
# install Tomcat
    && mkdir -p "$CATALINA_HOME" "$CATALINA_HOME"/logs "$CATALINA_HOME"/ssl ${tempTomcatNativeDir} \
    && addgroup tomcat \
    && adduser -h $CATALINA_HOME -s /bin/sh -G tomcat -D -g "dockerfile-created-tomcat-user" tomcat \
    && chown tomcat:tomcat $CATALINA_HOME "$CATALINA_HOME"/logs "$CATALINA_HOME"/ssl ${tempTomcatNativeDir}

USER tomcat

RUN set -x \
    && wget "${tomcatDownloadUrl}" \
    && tar -xzf ${tomcatFilename} --strip-components=1 \
    && tar -xzf bin/tomcat-native.tar.gz -C ${tempTomcatNativeDir} --strip-components=1

USER root

ADD server.xml $CATALINA_HOME/conf
ADD web.xml $CATALINA_HOME/conf

RUN set -x \
# compile & install Tomcat Native
    && apk add --no-cache --progress --virtual .native-build-deps \
            apr-dev \
            coreutils \
            dpkg-dev dpkg \
            gcc \
            libc-dev \
            make \
            openssl \
            openssl-dev \
            openjdk${alpineOpenJdkMajorVersion}="${alpineOpenJdkVersion}" \
    && ( \
       cd ${tempTomcatNativeDir}/native \
       && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
       && ./configure \
            --build="$gnuArch" \
            --libdir="${tomcatNativeLibDir}" \
            --prefix="$CATALINA_HOME" \
            --with-apr="$(which apr-1-config)" \
            --with-java-home=/usr/lib/jvm/java-1.${alpineOpenJdkMajorVersion}-openjdk \
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
    && apk add --virtual .tomcat-native-rundeps $runDeps \
# enable SSL
	&& openssl req -newkey rsa:2048 -x509 -keyout $CATALINA_HOME/ssl/server.pem -out $CATALINA_HOME/ssl/server.crt -nodes -subj '/CN=${sslCertCommonName}' \
# harden Tomcat: https://www.owasp.org/index.php/Securing_tomcat	
    && chown tomcat:tomcat $CATALINA_HOME/conf/server.xml $CATALINA_HOME/conf/web.xml \
    && chmod 400 $CATALINA_HOME/LICENSE $CATALINA_HOME/NOTICE \
    && chmod -R 400 $CATALINA_HOME/conf/* \
    && chmod 500 $CATALINA_HOME/bin $CATALINA_HOME/conf $CATALINA_HOME/ssl $CATALINA_HOME/lib \
    && chmod 300 $CATALINA_HOME/logs \
    && chmod -w $CATALINA_HOME \
    && chmod -w -R $CATALINA_HOME/bin/* $CATALINA_HOME/include/* $CATALINA_HOME/lib/* $CATALINA_HOME/native-jni-lib/* \
                   $CATALINA_HOME/ssl/* \
    && rm -rf $CATALINA_HOME/webapps/* \
# clean up ...
    && apk del --purge .native-build-deps \
    && rm -rf ${tempTomcatNativeDir} \
    && rm -f ${tomcatFilename} \
    && rm -f $CATALINA_HOME/RELEASE-NOTES \
    && rm -f $CATALINA_HOME/RUNNING.txt \
    && rm -f bin/tomcat-native.tar.gz \
# harden Alpine
# credit ... adapted from: https://gist.github.com/kost/017e95aa24f454f77a37
# Remove existing crontabs, if any.
    && rm -rf /var/spool/cron \
    && rm -rf /etc/crontabs \
    && rm -rf /etc/periodic \
# Remove all but a handful of admin commands.
    && find /sbin /usr/sbin ! -type d \
    	-a ! -name nologin \
    	-delete \
# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
    && find / -xdev -type d -perm +0002 -exec chmod o-w {} + \
    && find / -xdev -type f -perm +0002 -exec chmod o-w {} + \
    # Remove unnecessary user accounts.
    && sed -i -r '/^(tomcat|root)/!d' /etc/group \
    && sed -i -r '/^(tomcat|root)/!d' /etc/passwd
    && sysdirs=" \
 		/bin \
  		/etc \
  		/lib \
  		/sbin \
  		/usr \
	" \
# Remove apk configs.
	&& find $sysdirs -xdev -regex '.*apk.*' -exec rm -fr {} +
    

#USER tomcat
EXPOSE 8443
CMD ["catalina.sh", "run"]