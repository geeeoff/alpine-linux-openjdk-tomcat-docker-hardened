ARG alpineLinuxVersion=3.6

FROM alpine:${alpineLinuxVersion} AS alpine-linux

ARG alpineLinuxVersion
ARG alpineOpenJdkVersion=8.131.11-r2
ARG tomcatMajorVersion=8
ARG tomcatMinorVersion=5
ARG tomcatPatchVersion=20
ARG tomcatVersion=${tomcatMajorVersion}.${tomcatMinorVersion}.${tomcatPatchVersion}

#ENV ALPINE_JAVA_VERSION ${alpineOpenJdkVersion}
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $PATH:$CATALINA_HOME/bin
#ENV TOMCAT_MAJOR_VERSION 8
#ENV TOMCAT_MINOR_VERSION 5
#ENV TOMCAT_PATCH_VERSION 20
#ENV TOMCAT_VERSION $TOMCAT_MAJOR_VERSION.$TOMCAT_MINOR_VERSION.$TOMCAT_PATCH_VERSION
#ENV TOMCAT_VERSION ${tomcatVersion}

ARG tomcatFilename=apache-tomcat-${tomcatVersion}.tar.gz
ARG tomcatDownloadUrl=http://apache.org/dist/tomcat/tomcat-${tomcatMajorVersion}/v${tomcatVersion}/bin/${tomcatFilename}
ARG tomcatNativeLibDir=$CATALINA_HOME/native-jni-lib

ARG tempTomcatNativeDir=/tmp/tomcat-native

ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${tomcatNativeLibDir}
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV PATH $PATH:$JAVA_HOME/bin

WORKDIR $CATALINA_HOME

# install JRE
RUN set -x \
#    && apk update \
    && apk add \
        --no-cache \
        --progress \
            openjdk8-jre="${alpineOpenJdkVersion}" \
# install Tomcat
#RUN set -x \
    && mkdir -p "$CATALINA_HOME" \
    && mkdir -p ${tempTomcatNativeDir} \
#RUN set -x \
    && wget \
        "${tomcatDownloadUrl}" \
    && tar -xzf ${tomcatFilename} --strip-components=1 \
    && tar -xzf bin/tomcat-native.tar.gz -C ${tempTomcatNativeDir} --strip-components=1 \
    && rm -f $TOMCAT_FILE_NAME \
    && rm -f bin/tomcat-native.tar.gz \
# compile & install Tomcat Native
#RUN set -x \
    && apk add --no-cache --progress --virtual .native-build-deps \
            apr-dev \
            coreutils \
            dpkg-dev dpkg \
            gcc \
            libc-dev \
            make \
            openssl-dev \
            openjdk8="${alpineOpenJdkVersion}" \
#RUN set -x \
    && ( \
       cd ${tempTomcatNativeDir}/native \
       && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
       && ./configure \
            --build="$gnuArch" \
            --libdir="${tomcatNativeLibDir}" \
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
    && apk add --virtual .tomcat-native-rundeps $runDeps \
# clean up ...    
#RUN set -x \
    && apk del --purge .native-build-deps \
    && rm -rf ${tempTomcatNativeDir}
    
EXPOSE 8080
CMD ["catalina.sh", "run"]