# Ferocrypt

A simple script to generate **Let's Encrypt** wildcard certificates and install them on **Ferozo** hosting accounts via the **DonWeb** reseller API.

It fails sometimes. If it does, try later, seriously; I haven't got the time to debug it

## Setup

The script needs the DonWeb session token (the `sitio` cookie value). There are two providers to obtain it:

- **Web** (default): opens a Brave Browser window for manual login and extracts the cookie automatically. Requires `CHROMIUM_PATH` pointing to the Brave binary.
- **Env**: reads the token from the `DONWEB_TOKEN` environment variable (supports `.env` files).

## Usage

```shell
ruby lib/ferocrypt.rb your@email                # uses web provider (default)
ruby lib/ferocrypt.rb your@email Env            # uses env provider
```

## Disclaimer

For educational purposes only
