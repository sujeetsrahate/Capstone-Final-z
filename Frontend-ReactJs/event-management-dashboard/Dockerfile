FROM 026090548352.dkr.ecr.us-east-1.amazonaws.com/node-18-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM 026090548352.dkr.ecr.us-east-1.amazonaws.com/nginx-alpine

WORKDIR /usr/share/nginx/html
RUN rm -rf ./*

COPY --from=builder /usr/src/app/build .

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]










# FROM node:18-alpine AS builder
# WORKDIR /usr/src/app
# COPY package*.json ./
# RUN npm install
# COPY . .
# RUN npm run build

# FROM nginx:alpine
# WORKDIR /usr/share/nginx/html
# RUN rm -rf ./*
# COPY --from=builder /usr/src/app/build .
# EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"]
