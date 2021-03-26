# Container image that runs your code
FROM node:12-alpine

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm link

# Code file to execute when the docker container starts up (`entrypoint.sh`)
WORKDIR /usr/src/app/bin
ENTRYPOINT ["/usr/src/app/bin/start-local-node.sh"]
