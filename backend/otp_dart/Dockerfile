FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml /app/
RUN dart pub get
COPY . /app
RUN dart pub get

FROM dart:stable AS runtime
WORKDIR /app
COPY --from=build /app /app
ENV PORT=8080
CMD ["dart", "bin/server.dart"]
