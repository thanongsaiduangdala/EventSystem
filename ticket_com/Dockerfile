FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

# Pre-fetch deps at build time so first `flutter run` is faster;
# the volume mount will override this with your live code anyway.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

EXPOSE 8081