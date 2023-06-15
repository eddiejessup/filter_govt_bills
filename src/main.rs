use rss::Channel;
use tiny_http::{Response, Server};
use std::env;

const RSS_FEED_URL: &str = "https://bills.parliament.uk/rss/publicbills.rss";
const RSS_FEED_PATH: &str = "/bills.rss";

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

fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| String::from("80"));
    let server = Server::http(format!("0.0.0.0:{}", port)).unwrap();

    for request in server.incoming_requests() {
        if request.url() == RSS_FEED_PATH {
            let orig_channel = fetch_parse_rss_feed().unwrap();
            let filtered_channel = filter_rss_channel(orig_channel);
            let response = Response::from_string(filtered_channel.to_string()).with_header(
                tiny_http::Header::from_bytes("Content-Type", "application/rss+xml").unwrap(),
            );
            request.respond(response).unwrap();
        }
    }
}
