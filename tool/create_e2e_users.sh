#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${1:-$root_dir/.env.dev}"
out_dir="$root_dir/.e2e"
out_file="$out_dir/test-users.json"
service_key_file="$out_dir/service-role.key"

if [[ ! -f "$env_file" ]]; then
  echo "Arquivo de ambiente não encontrado: $env_file" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

: "${SUPABASE_URL:?SUPABASE_URL ausente}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY ausente}"

mkdir -p "$out_dir"
chmod 700 "$out_dir"
run_id="$(date -u +%Y%m%d%H%M%S)"
roles=(owner partner teen viewer individual contributor auditor mobile receipts categories)
users='[]'

for role in "${roles[@]}"; do
  email="financa.qa+${run_id}-${role}@example.com"
  password="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-20)Aa7!"
  display_name="QA ${role^}"
  if [[ -s "$service_key_file" ]]; then
    service_key="$(<"$service_key_file")"
    payload="$(jq -nc \
      --arg email "$email" \
      --arg password "$password" \
      --arg name "$display_name" \
      '{email:$email,password:$password,email_confirm:true,user_metadata:{display_name:$name}}')"
    endpoint="$SUPABASE_URL/auth/v1/admin/users"
    api_key="$service_key"
    authorization="Authorization: Bearer $service_key"
  else
    payload="$(jq -nc \
      --arg email "$email" \
      --arg password "$password" \
      --arg name "$display_name" \
      '{email:$email,password:$password,data:{display_name:$name}}')"
    endpoint="$SUPABASE_URL/auth/v1/signup"
    api_key="$SUPABASE_ANON_KEY"
    authorization="Authorization: Bearer $SUPABASE_ANON_KEY"
  fi

  response_file="$(mktemp)"
  status="$(curl --silent --show-error \
    "$endpoint" \
    -H "apikey: $api_key" \
    -H "$authorization" \
    -H "Content-Type: application/json" \
    --output "$response_file" \
    --write-out '%{http_code}' \
    --data "$payload")"
  response="$(<"$response_file")"
  rm -f "$response_file"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "Cadastro falhou para papel $role (HTTP $status)" >&2
    jq '{error,error_code,error_description,msg,code}' <<<"$response" >&2
    exit 1
  fi

  user_id="$(jq -r '.user.id // .id // empty' <<<"$response")"
  has_session="$(jq -r '(.access_token // .session.access_token // "") != ""' <<<"$response")"
  if [[ -z "$user_id" ]]; then
    echo "Cadastro falhou para papel $role" >&2
    jq '{error,error_description,msg,code}' <<<"$response" >&2
    exit 1
  fi

  users="$(jq -c \
    --arg role "$role" \
    --arg email "$email" \
    --arg password "$password" \
    --arg name "$display_name" \
    --arg user_id "$user_id" \
    --argjson has_session "$has_session" \
    '. + [{role:$role,email:$email,password:$password,display_name:$name,user_id:$user_id,has_session:$has_session}]' \
    <<<"$users")"
done

jq -n --arg run_id "$run_id" --argjson users "$users" \
  '{run_id:$run_id,created_at:(now|todate),users:$users}' >"$out_file"
chmod 600 "$out_file"

echo "Criados $(jq '.users | length' "$out_file") usuários."
echo "Credenciais salvas localmente em $out_file (ignorado pelo Git)."
echo "Sessões imediatas: $(jq '[.users[] | select(.has_session)] | length' "$out_file")."
