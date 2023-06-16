FROM rust:1.67 as builder
WORKDIR /usr/src/filter_govt_bills
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/
RUN cargo build --release
RUN cargo install --path . --target-dir /usr/src/filter_govt_bills/target
FROM debian:bullseye-slim
COPY --from=builder /usr/src/filter_govt_bills/target/release/filter_govt_bills /usr/local/bin/filter_govt_bills
CMD ["filter_govt_bills"]
