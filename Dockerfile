FROM node

ENV APP=/usr/src/app
ADD . $APP

WORKDIR $APP

RUN  apt-get update \
&&  apt-get install -y git-core vim \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* \
&&  npm config set fetch-retry-maxtimeout 6000000 \
&&  npm config set fetch-retry-mintimeout 1000000 \
&&  npm install

CMD npm test
