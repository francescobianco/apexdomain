
module domain
module probe
module report

main() {
  local domain
  local records

  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    apexdomain_report_usage
    return 0
  fi

  if [ "$#" -ne 1 ]; then
    apexdomain_report_usage >&2
    return 2
  fi

  if ! apexdomain_domain_have_command curl; then
    printf 'apexdomain: curl is required\n' >&2
    return 127
  fi

  domain="$(apexdomain_domain_normalize "$1")"

  if ! apexdomain_domain_validate_apex "$domain"; then
    printf 'apexdomain: expected an apex domain like example.com, got: %s\n' "$1" >&2
    return 2
  fi

  records="$(apexdomain_probe_domain "$domain")"
  apexdomain_report_domain "$domain" "$records"
}
