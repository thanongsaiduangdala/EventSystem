FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter pub get

ARG API_BASE_URL=http://localhost:8000
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80