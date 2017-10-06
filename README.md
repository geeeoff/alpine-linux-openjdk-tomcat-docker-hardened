# Alpine Linux running OpenJDK8 and Apache Tomcat on Docker => Hardened
A Docker project for Alpine Linux that has been hardened using various sources on the internet and is running the OpenJDK8 JRE and Apache Tomcat - no JDK is installed for security.

The image is minimal in size also:
[![](https://images.microbadger.com/badges/image/gyaworski/alpine-linux-openjdk-apache-tomcat-hardened.svg)](https://microbadger.com/images/gyaworski/alpine-linux-openjdk-apache-tomcat-hardened "Get your own image badge on microbadger.com")

To use:
`docker pull  gyaworski/alpine-linux-openjdk-apache-tomcat-hardened:alpine-3.6-openjdk-8.131.11-r2-apache-tomcat-8.5.20-hardened-1.0` or `docker pull  gyaworski/alpine-linux-openjdk-apache-tomcat-hardened:latest`

To login to container:
`docker run -it --rm gyaworski/alpine-linux-openjdk-apache-tomcat-hardened:alpine-3.6-openjdk-8.131.11-r2-apache-tomcat-8.5.20-hardened-1.0 /bin/ash` or `docker run -it --rm gyaworski/alpine-linux-openjdk-apache-tomcat-hardened:latest /bin/ash`

[Docker Hub repo is here](https://hub.docker.com/r/gyaworski/alpine-linux-openjdk-apache-tomcat-hardened/)

live. contribute. thrive.  
:smile: :rocket: :muscle:
