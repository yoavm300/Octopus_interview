FROM node:20-alpine AS build

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

FROM node:20-alpine

RUN apk update && apk upgrade --no-cache

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# npm/npx aren't needed at runtime (CMD invokes node directly); dropping them
# also drops their bundled vulnerable deps (tar/glob/brace-expansion etc.)
# that image scanners otherwise flag as part of the final image.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

USER node
EXPOSE 3000

CMD ["node", "src/server.js"]
