#I still can't use Scratch, so I use ubuntu:20.04 here
FROM ubuntu:20.04 AS build
ENV DEBIAN_FRONTEND noninteractive
ENV PATH="${PATH}:/root/.cargo/bin"
ENV OPENSSL="/usr/include/openssl/"


WORKDIR /src
RUN apt-get update &&  apt-get install -y git curl python3 pkg-config libssl-dev build-essential

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.rs && chmod a+x rustup.rs 
RUN sh rustup.rs -y
RUN rustup target add wasm32-wasi

RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s - -p /usr/local
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-tensorflowlite

COPY Cargo.toml .
COPY src ./src
COPY examples ./examples
# Build the WASM binary
RUN cargo build --target wasm32-wasi --example=object_detection --release --package=mediapipe-rs
RUN wasmedge compile target/wasm32-wasi/release/examples/object_detection.wasm target/wasm32-wasi/release/examples/object_detection_aot.wasm

FROM ubuntu:20.04
ENV PATH="${PATH}:/root/.wasmedge/bin/"
ENV WASMEDGE_LIB_DIR="/root/.wasmedge/lib"
ENV C_INCLUDE_PATH="$C_INCLUDE_PATH:/root/.wasmedge/include"
ENV LIBRARY_PATH="$LIBRARY_PATH:/root/.wasmedge/lib"
ENV WASMEDGE_PLUGIN_PATH="/root/.wasmedge/plugin"
RUN apt-get update &&  apt-get install -y git curl python3
COPY --link --from=build /src/target/wasm32-wasi/release/examples/object_detection_aot.wasm /object_detection_aot.wasm
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s - -p /usr/local
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-tensorflowlite

ENTRYPOINT [ "wasmedge", "run", "--dir=/", "object_detection_aot.wasm"]
#CMD [ "wasmedge", "run", "--dir=/", "object_detection_aot.wasm", "modle.tlf", "img.jpg", "result/output.jpg"]
#docker run --rm -it -v ./assets/models/object_detection/efficientdet_lite2_uint8.tflite:/modle.tlf -v ./assets/testdata/img/cat_and_dog.jpg:/img.jpg  -v ./result:/result  objectdetect-wasm:latest   modle.tlf img.jpg result/output.jpg
