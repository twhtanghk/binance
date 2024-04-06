FROM node

ENV APP=/usr/src/app
ADD . $APP

WORKDIR $APP

RUN  apt-get update \
&&  apt-get install -y git-core vim \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* \
&&  npm i --no-audit \
&&  (cd node_modules/binance; npm i axios@0.27.2)

CMD npm test
