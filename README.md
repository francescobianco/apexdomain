# apexdomain

`apexdomain` checks whether every common entrypoint for an apex domain reaches
the expected website:

- `http://domain`
- `https://domain`
- `http://www.domain`
- `https://www.domain`

It follows redirects with `curl`, reports the final URL, HTTP status, redirect
count, remote IP, TLS verification result, and prints a short diagnosis for
common apex/www problems.

## Usage

```sh
mush build
target/debug/apexdomain example.com
```

The input must be an apex domain such as `example.com`; `www.example.com` is
rejected because the tool derives the `www` entrypoints itself.

## Configuration

Runtime behavior can be tuned with environment variables:

- `APEXDOMAIN_CONNECT_TIMEOUT` defaults to `8`
- `APEXDOMAIN_MAX_TIME` defaults to `20`
- `APEXDOMAIN_MAX_REDIRECTS` defaults to `10`

## Modules

- `src/main.sh` handles CLI orchestration.
- `src/domain.sh` normalizes and validates apex domains.
- `src/probe.sh` runs `curl` and parses probe records.
- `src/report.sh` renders tables and diagnosis output.
