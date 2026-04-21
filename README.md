# apexdomain

A diagnostic tool that checks whether every common entrypoint for an apex domain reaches the expected website.

## What it does

`apexdomain` probes four URLs for a given domain:

- `http://domain`
- `https://domain`
- `http://www.domain`
- `https://www.domain`

It follows redirects with `curl` and reports:
- Final URL after all redirects
- HTTP status code
- Redirect count
- TLS verification result
- Response time
- Remote IP (with `--details`)

Then it provides a short diagnosis for common apex/www problems.

## Install

```sh
git clone https://github.com/anomalyco/apexdomain.git
cd apexdomain
mush build
```

Requires: `mush` (see [mush.javanile.org](https://mush.javanile.org))

## Usage

```sh
./target/debug/apexdomain example.com
./target/debug/apexdomain --details example.com
./target/debug/apexdomain https://www.example.com/path
```

The tool normalizes the input:
- `www.example.com` → `example.com`
- `https://example.com/` → `example.com`
- `http://www.example.com/path` → `example.com`

Use `--details` to include extra probe fields like remote IPs and curl error messages.

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `APEXDOMAIN_CONNECT_TIMEOUT` | 8 | Connection timeout in seconds |
| `APEXDOMAIN_MAX_TIME` | 20 | Total timeout in seconds |
| `APEXDOMAIN_MAX_REDIRECTS` | 10 | Maximum redirect hops |

## Modules

- `src/main.sh` — CLI orchestration
- `src/domain.sh` — domain normalization and validation
- `src/probe.sh` — curl probing and record parsing
- `src/report.sh` — table rendering and diagnosis output

## License

MIT