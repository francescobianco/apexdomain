apexdomain_domain_normalize() {
  local domain
  domain="$1"

  domain="${domain#http://}"
  domain="${domain#https://}"
  domain="${domain%%/*}"
  domain="${domain%%:*}"
  domain="${domain%.}"
  domain="${domain#www.}"

  printf '%s' "$domain" | tr '[:upper:]' '[:lower:]'
}

apexdomain_domain_validate_apex() {
  local domain
  domain="$1"

  if [ -z "$domain" ]; then
    return 1
  fi

  case "$domain" in
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
