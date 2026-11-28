FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Vite inlines VITE_* variables at build time, so the API URL is a build
# argument: docker build --build-arg VITE_API_BASE_URL=http://host:5000 .
ARG VITE_API_BASE_URL=http://localhost:5000
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# Production stage
FROM node:22-alpine

WORKDIR /app

# Install serve to run production build
RUN npm install -g serve

COPY --from=builder /app/dist ./dist

EXPOSE 80

CMD ["serve", "-s", "dist", "-l", "80"]
