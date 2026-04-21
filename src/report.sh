apexdomain_report_usage() {
  cat <<'EOF'
Usage:
  apexdomain <apex-domain>

Examples:
  apexdomain google.com
  apexdomain example.org

Checks every public entrypoint for an apex domain:
  http://apex
  https://apex
  http://www.apex
  https://www.apex

For each URL it reports curl reachability, HTTP status, redirects, final URL,
TLS verification, and then suggests likely DNS, redirect, or certificate fixes.
EOF
}

apexdomain_report_table() {
  local records
  local record
  local labels
  local label
  local url
  local exit_code
  local http_code
  local final_url
  local redirects
  local tls
  local time_total
  local remote_ip
  local status

  records="$1"
  labels="http-apex https-apex http-www https-www"

  printf '\nEntrypoint checks\n'
  printf '%-12s %-8s %-9s %-5s %-9s %-11s %s\n' 'entrypoint' 'result' 'http' 'tls' 'redirects' 'time' 'final_url'
  printf '%-12s %-8s %-9s %-5s %-9s %-11s %s\n' '----------' '------' '----' '---' '---------' '----' '---------'

  for label in $labels; do
    record="$(apexdomain_probe_find_record "$records" "$label")"
    url="$(apexdomain_probe_field "$record" url)"
    exit_code="$(apexdomain_probe_field "$record" exit_code)"
    http_code="$(apexdomain_probe_field "$record" http_code)"
    final_url="$(apexdomain_probe_field "$record" effective_url)"
    redirects="$(apexdomain_probe_field "$record" num_redirects)"
    time_total="$(apexdomain_probe_field "$record" time_total)"
    remote_ip="$(apexdomain_probe_field "$record" remote_ip)"
    status="$(apexdomain_probe_status_label "$exit_code" "$http_code")"
    tls="$(apexdomain_probe_tls_label "$url" "$exit_code" "$(apexdomain_probe_field "$record" ssl_verify_result)")"

    if [ -z "$http_code" ]; then
      http_code="-"
    fi
    if [ -z "$redirects" ]; then
      redirects="-"
    fi
    if [ -z "$time_total" ]; then
      time_total="-"
    else
      time_total="${time_total}s"
    fi
    if [ -z "$final_url" ]; then
      final_url="-"
    fi

    printf '%-12s %-8s %-9s %-5s %-9s %-11s %s\n' "$label" "$status" "$http_code" "$tls" "$redirects" "$time_total" "$final_url"

    if [ -n "$remote_ip" ]; then
      printf '  remote_ip: %s\n' "$remote_ip"
    fi
    if [ "$exit_code" != "0" ]; then
      printf '  curl_error: %s\n' "$(apexdomain_probe_curl_error "$record")"
    fi
  done
}

apexdomain_report_warn_entry() {
  local records
  local label
  local record
  local url
  local exit_code
  local http_code
  local tls
  local error

  records="$1"
  label="$2"
  record="$(apexdomain_probe_find_record "$records" "$label")"
  url="$(apexdomain_probe_field "$record" url)"
  exit_code="$(apexdomain_probe_field "$record" exit_code)"
  http_code="$(apexdomain_probe_field "$record" http_code)"
  tls="$(apexdomain_probe_tls_label "$url" "$exit_code" "$(apexdomain_probe_field "$record" ssl_verify_result)")"
  error="$(apexdomain_probe_curl_error "$record")"

  if [ "$exit_code" != "0" ]; then
    printf '%s %s is not healthy: curl exit %s' '-' "$label" "$exit_code"
    if [ -n "$error" ]; then
      printf ' (%s)' "$error"
    fi
    printf '.\n'
  elif [ "${http_code#4}" != "$http_code" ] || [ "${http_code#5}" != "$http_code" ]; then
    printf '%s %s returns HTTP %s after redirects; expected a 2xx page or a clean redirect chain.\n' '-' "$label" "$http_code"
  fi

  case "$tls" in
    FAIL*|CHECK)
      printf '%s %s has a TLS problem. Verify that the certificate covers this hostname and the full chain is installed.\n' '-' "$label"
      ;;
  esac
}

apexdomain_report_diagnosis() {
  local records
  local finals
  local final_count
  local apex_https
  local www_https

  records="$1"
  finals="$(apexdomain_probe_unique_successful_finals "$records")"
  final_count="$(printf '%s\n' "$finals" | sed '/^$/d' | wc -l | awk '{print $1}')"

  printf '\nDiagnosis\n'

  apexdomain_report_warn_entry "$records" "http-apex"
  apexdomain_report_warn_entry "$records" "https-apex"
  apexdomain_report_warn_entry "$records" "http-www"
  apexdomain_report_warn_entry "$records" "https-www"

  if [ "$final_count" -eq 0 ]; then
    printf '%s\n' '- No successful entrypoint was found. Check DNS first, then the web server and TLS termination.'
    return
  fi

  if [ "$final_count" -eq 1 ]; then
    printf '%s All successful entrypoints converge to: %s\n' '-' "$finals"
  else
    printf '%s\n' '- Successful entrypoints do not converge to a single canonical URL. Current final URLs:'
    printf '%s\n' "$finals" | sed 's/^/  - /'
  fi

  apex_https="$(apexdomain_probe_find_record "$records" "https-apex")"
  www_https="$(apexdomain_probe_find_record "$records" "https-www")"

  if [ "$(apexdomain_probe_field "$apex_https" exit_code)" = "0" ] && [ "$(apexdomain_probe_field "$www_https" exit_code)" != "0" ]; then
    printf '%s The apex HTTPS entrypoint works but www HTTPS does not. This is commonly a missing www DNS record or a certificate without www.%s in SANs.\n' '-' "$(apexdomain_probe_field "$apex_https" url | sed 's#^https://##')"
  fi

  if [ "$(apexdomain_probe_field "$www_https" exit_code)" = "0" ] && [ "$(apexdomain_probe_field "$apex_https" exit_code)" != "0" ]; then
    printf '%s\n' '- The www HTTPS entrypoint works but apex HTTPS does not. Check apex A/AAAA/ALIAS records and include the apex name in the certificate SANs.'
  fi
}

apexdomain_report_domain() {
  local domain
  local records

  domain="$1"
  records="$2"

  printf 'Domain: %s\n' "$domain"
  printf 'Timeouts: connect=%ss total=%ss max_redirects=%s\n' "$APEXDOMAIN_CONNECT_TIMEOUT" "$APEXDOMAIN_MAX_TIME" "$APEXDOMAIN_MAX_REDIRECTS"

  apexdomain_report_table "$records"
  apexdomain_report_diagnosis "$records"
}
