use rss::Channel;
use std::{env, process};
use tiny_http::{Response, Server};

const RSS_FEED_URL: &str = "https://bills.parliament.uk/rss/publicbills.rss";
const RSS_FEED_PATH: &str = "/bills.rss";

#[derive(Debug)]
enum StartupError {
    ConfigError(env::VarError),
    ServerError(Box<dyn std::error::Error + Send + Sync + 'static>),
}

#[derive(Debug)]
enum FetchError {
    DecodeError(std::io::Error),
    ParseError(rss::Error),
    RequestError(ureq::Error),
}

fn fetch_rss_feed() -> Result<String, FetchError> {
    let resp = ureq::get(RSS_FEED_URL)
        .call()
        .map_err(|e| FetchError::RequestError(e))?;
    resp.into_string().map_err(|e| FetchError::DecodeError(e))
}
fn fetch_parse_rss_feed() -> Result<Channel, FetchError> {
    let content = fetch_rss_feed()?;
    content
        .parse::<Channel>()
        .map_err(|e: rss::Error| FetchError::ParseError(e))
}

fn filter_rss_channel(channel: Channel) -> Channel {
    let mut filtered = channel.clone();
    filtered.set_items(
        channel
            .items()
            .iter()
            .filter(|item| {
                // Check if the item has a category "Government Bill"
                item.categories()
                    .iter()
                    .any(|category| category.name() == "Government Bill")
            })
            .cloned()
            .collect::<Vec<rss::Item>>(),
    );
    filtered
}

fn get_server() -> Result<Server, StartupError> {
    let port = env::var("PORT").map_err(|e| StartupError::ConfigError(e))?;
    Server::http(format!("0.0.0.0:{}", port)).map_err(|e| StartupError::ServerError(e))
}

fn main() {
    let server = match get_server() {
        Ok(val) => val,
        Err(e) => {
            eprintln!("Error: {:?}", e);
            process::exit(1);
        }
    };

    let rss_header = match tiny_http::Header::from_bytes("Content-Type", "application/rss+xml") {
        Ok(val) => val,
        Err(e) => {
            eprintln!("Could not build RSS content-type header: {:?}", e);
            process::exit(1);
        }
    };

    for request in server.incoming_requests() {
        let response = if request.url() == RSS_FEED_PATH {
            match fetch_parse_rss_feed() {
                Ok(orig_channel) => {
                    let filtered_channel = filter_rss_channel(orig_channel);
                    Response::from_string(filtered_channel.to_string())
                        .with_header(rss_header.clone())
                }
                Err(e) => {
                    Response::from_string(format!("Error while fetching source RSS: {:?}", e))
                        .with_status_code(500)
                }
            }
        } else {
            Response::from_string("Invalid path").with_status_code(404)
        };
        match request.respond(response) {
            Ok(_) => (),
            Err(e) => println!("Error while sending response: {}", e),
        }
    }
}
