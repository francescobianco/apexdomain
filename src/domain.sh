apexdomain_domain_normalize() {
  local domain
  domain="$1"

  domain="${domain#http://}"
  domain="${domain#https://}"
  domain="${domain%%/*}"
  domain="${domain%%:*}"
  domain="${domain%.}"

  printf '%s' "$domain" | tr '[:upper:]' '[:lower:]'
}

apexdomain_domain_validate_apex() {
  local domain
  domain="$1"

  if [ -z "$domain" ]; then
    return 1
  fi

  case "$domain" in
    www.*)
      return 1
      ;;
    *.*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

apexdomain_domain_have_command() {
  command -v "$1" >/dev/null 2>&1
}
