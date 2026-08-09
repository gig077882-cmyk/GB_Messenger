FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
    COPY prisma ./prisma/

    RUN npm install && npm cache clean --force

COPY . .

RUN npm run build
RUN npm run prisma:generate

FROM node:22-alpine AS production

WORKDIR /app

RUN apk add --no-cache ffmpeg

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/prisma ./prisma
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
