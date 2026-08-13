#!/usr/bin/env bash
set -u -o pipefail

DEFAULT_BASE_URL='https://db-orbit.com'
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOCAL_CONFIG="$SCRIPT_DIR/orbit-request.local.env"
LOCAL_BASE_URL=''
if [[ -f "$LOCAL_CONFIG" ]]; then
  while IFS= read -r config_line || [[ -n "$config_line" ]]; do
    [[ -z "$config_line" || "$config_line" == \#* ]] && continue
    if [[ "$config_line" == ORBIT_BASE_URL=* && -z "$LOCAL_BASE_URL" ]]; then
      LOCAL_BASE_URL=${config_line#ORBIT_BASE_URL=}
      if [[ "$LOCAL_BASE_URL" == \"*\" && "$LOCAL_BASE_URL" == *\" ]]; then
        LOCAL_BASE_URL=${LOCAL_BASE_URL:1:${#LOCAL_BASE_URL}-2}
      fi
    else
      printf 'orbit-request httpStatus=none curlExit=none method=GET path=none timeout=30 error=invalid_local_config\n' >&2
      exit 10
    fi
  done < "$LOCAL_CONFIG"
fi
BASE_URL="${ORBIT_BASE_URL:-${LOCAL_BASE_URL:-$DEFAULT_BASE_URL}}"
METHOD='GET'
PATH_VALUE=''
QUERY=''
TIMEOUT='30'
ALLOW_POST=0
BODY_FILE=''
BODY_STDIN=0
MULTIPART=0
FORM_FIELDS=()
FORM_FILES=()

usage() {
  cat <<'EOF'
Usage:
  orbit-request.sh --method GET --path /api/... [--query 'key=value&...'] [--timeout 30]
  orbit-request.sh --method POST --path /api/... --allow-post [--body-file request.json | --body-stdin] [--timeout 30]
  orbit-request.sh --method POST --path /api/... --allow-post --multipart [--form-field 'name=value']... [--form-file 'name=path']... [--timeout 30]

Writes the native response body to stdout and one status line to stderr.
Exit codes: 0=2xx HTTP response, 10=invalid local arguments, 20=curl/transport failure, 21=non-2xx HTTP response.
EOF
}

fail_local() {
  printf 'orbit-request httpStatus=none curlExit=none method=%s path=%s timeout=%s error=%s\n' "$METHOD" "${PATH_VALUE:-none}" "$TIMEOUT" "$1" >&2
  exit 10
}

while (($#)); do
  case "$1" in
    --method) (($# >= 2)) || fail_local 'missing_method'; METHOD=$2; shift 2 ;;
    --path) (($# >= 2)) || fail_local 'missing_path'; PATH_VALUE=$2; shift 2 ;;
    --query) (($# >= 2)) || fail_local 'missing_query'; QUERY=$2; shift 2 ;;
    --timeout) (($# >= 2)) || fail_local 'missing_timeout'; TIMEOUT=$2; shift 2 ;;
    --allow-post) ALLOW_POST=1; shift ;;
    --body-file) (($# >= 2)) || fail_local 'missing_body_file'; BODY_FILE=$2; shift 2 ;;
    --body-stdin) BODY_STDIN=1; shift ;;
    --multipart) MULTIPART=1; shift ;;
    --form-field) (($# >= 2)) || fail_local 'missing_form_field'; FORM_FIELDS+=("$2"); shift 2 ;;
    --form-file) (($# >= 2)) || fail_local 'missing_form_file'; FORM_FILES+=("$2"); shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail_local 'unknown_argument' ;;
  esac
done

[[ "$METHOD" == 'GET' || "$METHOD" == 'POST' ]] || fail_local 'unsupported_method'
[[ -n "$PATH_VALUE" ]] || fail_local 'missing_path'
[[ "$PATH_VALUE" == /api/* ]] || fail_local 'path_must_start_with_api'
[[ "$PATH_VALUE" != *'?'* && "$PATH_VALUE" != *'..'* ]] || fail_local 'unsafe_path'
[[ "$QUERY" != *$'\n'* && "$QUERY" != *$'\r'* ]] || fail_local 'unsafe_query'
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail_local 'invalid_timeout'

body_source_count=$BODY_STDIN
[[ -z "$BODY_FILE" ]] || ((body_source_count += 1))
(( body_source_count <= 1 )) || fail_local 'multiple_body_sources'
(( MULTIPART == 0 || body_source_count == 0 )) || fail_local 'mixed_body_modes'
(( MULTIPART == 1 || ${#FORM_FIELDS[@]} == 0 && ${#FORM_FILES[@]} == 0 )) || fail_local 'form_requires_multipart'

if [[ "$METHOD" == 'GET' ]]; then
  (( body_source_count == 0 && MULTIPART == 0 )) || fail_local 'get_cannot_have_body'
else
  (( ALLOW_POST == 1 )) || fail_local 'post_requires_allow_post'
fi

if [[ -n "$BODY_FILE" ]]; then
  [[ -f "$BODY_FILE" && -r "$BODY_FILE" ]] || fail_local 'unreadable_body_file'
fi

if (( MULTIPART == 1 )); then
  (( ${#FORM_FIELDS[@]} + ${#FORM_FILES[@]} > 0 )) || fail_local 'empty_multipart'
  for entry in "${FORM_FIELDS[@]}"; do
    [[ "$entry" == *=* ]] || fail_local 'invalid_form_field'
    name=${entry%%=*}
    value=${entry#*=}
    [[ "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || fail_local 'invalid_form_name'
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail_local 'unsafe_form_value'
  done
  for entry in "${FORM_FILES[@]}"; do
    [[ "$entry" == *=* ]] || fail_local 'invalid_form_file'
    name=${entry%%=*}
    file_path=${entry#*=}
    [[ "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || fail_local 'invalid_form_name'
    [[ "$file_path" != *$'\n'* && "$file_path" != *$'\r'* ]] || fail_local 'unsafe_form_file'
    [[ -f "$file_path" && -r "$file_path" ]] || fail_local 'unreadable_form_file'
  done
fi

[[ "$BASE_URL" =~ ^https?://[^/?#]+$ ]] || fail_local 'invalid_base_url'
API_KEY="${ORBIT_REQUEST_API_KEY-}"
[[ "$API_KEY" != *$'\n'* && "$API_KEY" != *$'\r'* ]] || fail_local 'invalid_api_key'
[[ -n "$API_KEY" && "$API_KEY" =~ [^[:space:]] ]] || fail_local 'missing_api_key'
command -v curl >/dev/null 2>&1 || fail_local 'curl_not_found'

url="${BASE_URL}${PATH_VALUE}"
[[ -z "$QUERY" ]] || url+="?${QUERY}"
body_path=$(mktemp "${TMPDIR:-/tmp}/orbit-request-body.XXXXXX") || fail_local 'cannot_create_temp_file'
trap 'rm -f "$body_path"' EXIT

curl_args=(
  --silent --show-error --request "$METHOD"
  --header 'Accept: application/json'
  --header "Authorization: Bearer ${API_KEY}"
  --max-time "$TIMEOUT"
  --output "$body_path"
  --write-out '%{http_code}'
  "$url"
)

if [[ "$METHOD" == 'POST' ]]; then
  if (( MULTIPART == 1 )); then
    for entry in "${FORM_FIELDS[@]}"; do
      curl_args+=(--form-string "$entry")
    done
    for entry in "${FORM_FILES[@]}"; do
      name=${entry%%=*}
      file_path=${entry#*=}
      curl_args+=(--form "${name}=@${file_path}")
    done
  else
    curl_args+=(--header 'Content-Type: application/json')
    if [[ -n "$BODY_FILE" ]]; then
      curl_args+=(--data-binary "@$BODY_FILE")
    elif (( BODY_STDIN == 1 )); then
      curl_args+=(--data-binary '@-')
    fi
  fi
fi

http_status=$(curl "${curl_args[@]}")
curl_exit=$?
cat "$body_path"

if (( curl_exit != 0 )); then
  printf 'orbit-request httpStatus=%s curlExit=%s method=%s path=%s timeout=%s error=transport\n' "${http_status:-none}" "$curl_exit" "$METHOD" "$PATH_VALUE" "$TIMEOUT" >&2
  exit 20
fi

printf 'orbit-request httpStatus=%s curlExit=0 method=%s path=%s timeout=%s\n' "$http_status" "$METHOD" "$PATH_VALUE" "$TIMEOUT" >&2
if [[ "$http_status" =~ ^2[0-9][0-9]$ ]]; then
  exit 0
fi
exit 21
