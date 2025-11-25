FROM node:16-alpine as builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:16-alpine

WORKDIR /app

# Install serve to run production build
RUN npm install -g serve

COPY --from=builder /app/build ./build

EXPOSE 80

CMD ["serve", "-s", "build", "-l", "80"]
