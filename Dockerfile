FROM node

ENV APP=/usr/src/app
ADD . $APP

WORKDIR $APP

RUN apt update \
&&  apt install -y apt-file \
&&  apt update \
&&  apt install -y git-core vim \
&&  apt clean \
&&  rm -rf /var/lib/apt/lists/* \
&&  npm i --no-audit \
&&  (cd node_modules/binance; npm i --no-audit axios@0.27.2)

CMD npm test
