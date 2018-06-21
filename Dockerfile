FROM drecom/ubuntu-ruby:2.5.1

RUN apt-get update && apt-get install -y libjsoncpp-dev libb64-dev

RUN cd /opt && git clone https://code.googlesource.com/re2 && cd re2 && git checkout 2018-02-01 && \
    make CFLAGS='-fPIC -c -Wall -Wno-sign-compare -O3 -g -I.' && make install && ldconfig
