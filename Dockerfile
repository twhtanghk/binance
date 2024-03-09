FROM node

ENV APP=/usr/src/app
ADD . $APP

WORKDIR $APP

RUN  apt-get update \
&&  apt-get install -y git-core vim \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /tmp/$(basename $SRC) \
&&  npm install

CMD npm test
