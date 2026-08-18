FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_HOME=/opt/flutter
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# Pre-cache and accept licenses
RUN flutter precache
RUN flutter doctor

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build apk --release

CMD ["echo", "Build complete: build/app/outputs/flutter-apk/app-release.apk"]