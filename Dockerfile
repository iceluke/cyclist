FROM debian:stretch
RUN apt-get update && apt-get install -y apt-utils
RUN apt-get update && apt-get install -y \
	wget \
	git \
	tar \
	make \
	gnupg \
	g++ \
	libstdc++-6-dev \
	python3 \
	libpython3-stdlib
RUN wget https://www.lrde.epita.fr/dload/spot/spot-2.2.1.tar.gz
RUN apt-get install -y python3-dev
RUN tar -xzf spot-2.2.1.tar.gz && cd spot-2.2.1 && ./configure && make && make install && cd ..
RUN apt-get update && apt-get install --no-install-recommends -y \
	ocaml-nox \
	ocaml-native-compilers \
	ocaml-melt \
	libpcre-ocaml-dev \
	libocamlgraph-ocaml-dev
RUN apt-get install -y unzip
RUN git clone https://github.com/iceluke/cyclist.git
WORKDIR "./cyclist"
RUN make
RUN chmod +x *.native
ENV PATH="/cyclist:$PATH"
