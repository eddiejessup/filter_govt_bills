# Rust RSS Server

A simple Rust server that fetches the RSS feed of UK parliamentary bills, and filters it to only include items with the category "Government Bill" It then serves the filtered RSS feed over HTTP.

Because the other bills don't matter.

## Installation

To build and run the server, you need to have Rust and Cargo installed on your system. You can install Rust and Cargo by following the instructions on the [official Rust website](https://www.rust-lang.org/tools/install).

Once you have Rust and Cargo installed, you can clone the repository and build the server using the following commands:

```bash
git clone https://github.com/your-username/rust-rss-server.git
cd rust-rss-server
cargo build --release
```

This will build the server in release mode and create an executable binary in the `target/release` directory.

## Usage

To run the server, you need to set the `$PORT` environment variable to the port number you want to use. For example, to run the server on port 8000, you can run the following command:

```bash
PORT=8000 ./target/release/rust-rss-server
```

This will start the server and listen for incoming requests on port 8000. You can then access the filtered RSS feed by visiting http://localhost:8000/bills.rss.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
