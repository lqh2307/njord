FROM debian:bookworm AS builder

RUN apt-get update -y \
	&& apt-get upgrade -y \
	&& apt-get install -y \
		build-essential \
		cmake \
		swig \
		libproj-dev \
		libjson-c-dev \
		openjdk-17-jdk-headless \
		openjdk-17-source \
		ant \
		wget \
		git \
	&& apt-get -y --purge autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64/
ENV JAVADOC=/usr/lib/jvm/java-17-openjdk-amd64/bin/javadoc
ENV JAVAC=/usr/lib/jvm/java-17-openjdk-amd64/bin/javac
ENV JAVA=/usr/lib/jvm/java-17-openjdk-amd64/bin/java
ENV JAR=/usr/lib/jvm/java-17-openjdk-amd64/bin/jar
ENV JAVA_INCLUDE="-I/usr/lib/jvm/java-17-openjdk-amd64/include -I/usr/lib/jvm/java-17-openjdk-amd64/include/linux"

WORKDIR /build

ENV GDAL_VERSION=3.10.0

RUN wget -q http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.xz \
	&& tar -xf ./gdal-$GDAL_VERSION.tar.xz \
	&& rm -rf ./gdal-$GDAL_VERSION.tar.xz \
	&& cd ./gdal-$GDAL_VERSION \
	&& mkdir -p /opt/gdal \
	&& cmake -S . -B build \
		-DCMAKE_INSTALL_RPATH=/opt/gdal \
		-DBUILD_JAVA_BINDINGS=ON \
		-DCMAKE_INSTALL_PREFIX=/opt/gdal \
		-DCMAKE_INSTALL_LIBDIR=/opt/gdal \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_VERBOSE_MAKEFILE=ON \
		-Wno-dev \
		-DBUILD_TESTING=OFF \
	&& cmake --build build \
	&& cmake --install build

WORKDIR /build/njord

ADD . .

RUN ./gradlew :chart_server:installDist \
	&& ./gradlew :web:jsBrowserDistribution


FROM debian:bookworm AS runner

ENV JAVA_OPTS="-Dconfig.file=/opt/chart_server/application.conf -Dcharts.webStaticContent=/opt/chart_server/public -Djava.library.path=/opt/gdal/jni"

RUN apt-get update -y \
	&& apt-get upgrade -y \
	&& apt-get install -y \
		openjdk-17-jre-headless \
		libcurl3-gnutls \
		libdeflate0 \
		libtiff6 \
		libproj25 \
		libjson-c5 \
	&& apt-get -y --purge autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/gdal /opt/gdal
COPY --from=builder /build/njord/chart_server/build/install /opt
COPY --from=builder /build/njord/chart_server/src/jvmMain/resources/application.conf /opt/chart_server/application.conf
COPY --from=builder /build/njord/chart_server/libs/jmx-agent.jar /opt/chart_server/jmx-agent.jar
COPY --from=builder /build/njord/web/build/dist/js/productionExecutable /opt/chart_server/public

CMD ["/opt/chart_server/bin/chart_server"]
