FROM nginx
# COPY site /usr/share/nginx/html
# FROM phusion/passenger-ruby26:1.0.9 AS base

# From Phusion
# ENV HOME /root
# RUN rm /etc/nginx/sites-enabled/default
# ADD config/docker/nginx/gzip_max.conf /etc/nginx/conf.d/gzip_max.conf

LABEL Description="Intuitive local web frontend for the BLAST bioinformatics tool"
LABEL MailingList="https://groups.google.com/forum/#!forum/sequenceserver"
LABEL Website="http://www.sequenceserver.com"
LABEL Version="1.1.0 beta"

RUN apt-get update  && apt-get install -y --no-install-recommends \
        build-essential \
        ruby ruby-dev \
        curl wget \
        gnupg \
        git \
        zlib1g-dev

VOLUME ["/db"]
EXPOSE 4567

COPY site /site
RUN chmod +r /site
COPY config/nginx/default.conf /etc/nginx/sites-enabled/default.conf
COPY exe/init.sh /sbin/init.sh

RUN git clone https://github.com/wurmlab/sequenceserver.git /sequenceserver
WORKDIR /sequenceserver
RUN gem install bundler --no-rdoc --no-ri && bundle install --without=development
RUN yes '' | bundle exec bin/sequenceserver -s

RUN chmod +x /sbin/init.sh 

CMD ["/sbin/init.sh"]

# ENTRYPOINT ["bundle", "exec", "bin/sequenceserver", "-d", "db"]
