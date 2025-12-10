# Ferocrypt

A simple script to generate **Let's Encrypt** certificates and upload them to your **Ferozo** account.

It fails sometimes. If it does, try later, seriously; I haven't got the time to debug it

## Setup

You need a 1Password account.

1. Install and setup `1Password CLI`.
2. Add an item named `DonWeb` to your vault.
3. Add a field named `PHPSESSID` to that item with the value of the `sitio` cookie from `donweb.com` (log in first).

## Usage

```shell
ruby lib/ferocrypt.rb your@email
```

## TODO

- [ ] Tests

## Disclaimer

For educational purposes only
