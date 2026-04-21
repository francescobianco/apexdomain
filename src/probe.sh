APEXDOMAIN_CONNECT_TIMEOUT="${APEXDOMAIN_CONNECT_TIMEOUT:-8}"
APEXDOMAIN_MAX_TIME="${APEXDOMAIN_MAX_TIME:-20}"
APEXDOMAIN_MAX_REDIRECTS="${APEXDOMAIN_MAX_REDIRECTS:-10}"

apexdomain_probe_collect() {
  local label
  local url
  local output
  local exit_code

  label="$1"
  url="$2"

  output="$(
    curl \
      --silent \
      --show-error \
      --location \
      --max-redirs "$APEXDOMAIN_MAX_REDIRECTS" \
      --connect-timeout "$APEXDOMAIN_CONNECT_TIMEOUT" \
      --max-time "$APEXDOMAIN_MAX_TIME" \
      --output /dev/null \
      --write-out 'http_code=%{http_code}\neffective_url=%{url_effective}\nnum_redirects=%{num_redirects}\nssl_verify_result=%{ssl_verify_result}\ntime_total=%{time_total}\nremote_ip=%{remote_ip}\ncontent_type=%{content_type}\n' \
      "$url" 2>&1
  )"
  exit_code="$?"

  printf 'label=%s\n' "$label"
  printf 'url=%s\n' "$url"
  printf 'exit_code=%s\n' "$exit_code"
  printf '%s\n' "$output"
  printf '%s\n' '---'
}

apexdomain_probe_domain() {
  local domain
  domain="$1"

  apexdomain_probe_collect "http-apex" "http://${domain}"
  apexdomain_probe_collect "https-apex" "https://${domain}"
  apexdomain_probe_collect "http-www" "http://www.${domain}"
  apexdomain_probe_collect "https-www" "https://www.${domain}"
}

apexdomain_probe_field() {
  local record
  local key
  record="$1"
  key="$2"

  printf '%s\n' "$record" | awk -F= -v key="$key" '$1 == key { sub($1 FS, ""); print; exit }'
}

apexdomain_probe_curl_error() {
  local record
  record="$1"

  printf '%s\n' "$record" | awk -F= '
    $1 != "label" &&
    $1 != "url" &&
    $1 != "exit_code" &&
    $1 != "http_code" &&
    $1 != "effective_url" &&
    $1 != "num_redirects" &&
    $1 != "ssl_verify_result" &&
    $1 != "time_total" &&
    $1 != "remote_ip" &&
    $1 != "content_type" &&
    $0 != "" {
      print $0
      exit
    }
  '
}

apexdomain_probe_find_record() {
  local records
  local wanted
  records="$1"
  wanted="$2"

  printf '%s\n' "$records" | awk -v wanted="$wanted" '
    BEGIN { RS = "---\n"; ORS = "" }
    $0 ~ ("label=" wanted "\n") {
      print
      exit
    }
  '
}

apexdomain_probe_unique_successful_finals() {
  local records
  records="$1"

  printf '%s\n' "$records" | awk -F= '
    $1 == "exit_code" { ok = ($2 == "0") }
    $1 == "effective_url" && ok && $2 != "" {
      sub($1 FS, "")
      finals[$0] = 1
    }
    END {
      for (url in finals) {
        print url
      }
    }
  ' | sort
}

apexdomain_probe_status_label() {
  local exit_code
  local http_code
  exit_code="$1"
  http_code="$2"

  if [ "$exit_code" != "0" ]; then
    printf 'FAIL'
    return
  fi

  case "$http_code" in
    2*|3*)
      printf 'OK'
      ;;
    4*|5*)
      printf 'HTTP_%s' "$http_code"
      ;;
    *)
      printf 'UNKNOWN'
      ;;
  esac
}

apexdomain_probe_tls_label() {
  local url
  local exit_code
  local verify_result
  url="$1"
  exit_code="$2"
  verify_result="$3"

  case "$url" in
    https://*)
      if [ "$verify_result" = "0" ] && [ "$exit_code" = "0" ]; then
        printf 'OK'
      elif [ "$verify_result" = "0" ]; then
        printf 'CHECK'
      else
        printf 'FAIL(%s)' "$verify_result"
      fi
      ;;
    *)
      printf '%s' '-'
      ;;
  esac
}
