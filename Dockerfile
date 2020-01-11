FROM node:12-alpine

RUN apk add --no-cache bash git

RUN npm install -g anypoint-cli

COPY LICENSE README.md /

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
