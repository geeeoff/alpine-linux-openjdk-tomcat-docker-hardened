FROM alpine:3.6 AS alpine-linux

# look to use Docker tags instead of ENV if possible???

ENV ALPINE_JAVA_VERSION 8.131.11-r2
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $PATH:$CATALINA_HOME/bin
ENV TOMCAT_MAJOR_VERSION 8
ENV TOMCAT_MINOR_VERSION 5
ENV TOMCAT_PATCH_VERSION 20
ENV TOMCAT_VERSION $TOMCAT_MAJOR_VERSION.$TOMCAT_MINOR_VERSION.$TOMCAT_PATCH_VERSION
ENV TOMCAT_FILE_NAME apache-tomcat-$TOMCAT_VERSION.tar.gz
ENV TOMCAT_DOWNLOAD_URL http://apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR_VERSION/v$TOMCAT_VERSION/bin/$TOMCAT_FILE_NAME
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV TEMP_TOMCAT_NATIVEDIR /tmp/tomcat-native
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

#ENV ALPINE_NATIVE_TOMCAT_VERSION 1.2.12-r0
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV PATH $PATH:$JAVA_HOME/bin

# install JRE

RUN set -x \
    && apk update \
    && apk add \
        --no-cache \
        --progress \
            openjdk8-jre="$ALPINE_JAVA_VERSION"
            
    

# install Tomcat

RUN set -x \
    && mkdir -p "$CATALINA_HOME" \
    && mkdir -p $TEMP_TOMCAT_NATIVEDIR
    
WORKDIR $CATALINA_HOME

RUN set -x \
    && wget \
        "$TOMCAT_DOWNLOAD_URL" \
    && tar -xzf $TOMCAT_FILE_NAME --strip-components=1 \
    && tar -xzf bin/tomcat-native.tar.gz -C $TEMP_TOMCAT_NATIVEDIR --strip-components=1 \
    && rm -f $TOMCAT_FILE_NAME \
    && rm -f bin/tomcat-native.tar.gz
    
    
RUN set -x \
    && apk add --no-cache --progress --virtual .native-build-deps \
            apr-dev \
            coreutils \
            dpkg-dev dpkg \
            gcc \
            libc-dev \
            make \
            openssl-dev \
            openjdk8="$ALPINE_JAVA_VERSION"
            
RUN set -x \
    && ( \
#       export CATALINA_HOME="$PWD" \
       cd $TEMP_TOMCAT_NATIVEDIR/native \
       && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
       && ./configure \
            --build="$gnuArch" \
            --libdir="$TOMCAT_NATIVE_LIBDIR" \
            --prefix="$CATALINA_HOME" \
            --with-apr="$(which apr-1-config)" \
            --with-java-home=/usr/lib/jvm/java-1.8-openjdk \
            --with-ssl=yes \
       && make -j "$(nproc)" \
       && make install \
    ) \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive "$TOMCAT_NATIVE_LIBDIR" \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --virtual .tomcat-native-rundeps $runDeps
    
RUN set -x \
    && apk del .native-build-deps \
    && rm -rf $TEMP_TOMCAT_NATIVEDIR
    
EXPOSE 8080
CMD ["catalina.sh", "run"]
