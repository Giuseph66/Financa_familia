#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Fixture falhou na linha $LINENO." >&2' ERR

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
users_file="$root_dir/.e2e/test-users.json"
env_file="$root_dir/.env.dev"
summary_file="$root_dir/.e2e/fixture-summary.json"

[[ -f "$users_file" ]] || { echo "Execute create_e2e_users.sh primeiro." >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

login() {
  local role="$1" email password response
  email="$(jq -r --arg role "$role" '.users[] | select(.role == $role) | .email' "$users_file")"
  password="$(jq -r --arg role "$role" '.users[] | select(.role == $role) | .password' "$users_file")"
  response="$(curl --silent --show-error --fail-with-body \
    "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    --data "$(jq -nc --arg email "$email" --arg password "$password" '{email:$email,password:$password}')")"
  jq -er '.access_token' <<<"$response"
}

get_json() {
  local token="$1" path="$2"
  curl --silent --show-error --fail-with-body \
    "$SUPABASE_URL/rest/v1/$path" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $token"
}

post_json() {
  local token="$1" path="$2" payload="$3"
  curl --silent --show-error --fail-with-body \
    "$SUPABASE_URL/rest/v1/$path" \
    -X POST \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    --data "$payload"
}

patch_json() {
  local token="$1" path="$2" payload="$3"
  curl --silent --show-error --fail-with-body \
    "$SUPABASE_URL/rest/v1/$path" \
    -X PATCH \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    --data "$payload"
}

rpc() {
  local token="$1" name="$2" payload="$3"
  post_json "$token" "rpc/$name" "$payload"
}

owner_token="$(login owner)"
partner_token="$(login partner)"
teen_token="$(login teen)"
viewer_token="$(login viewer)"
auditor_token="$(login auditor)"

owner_id="$(jq -r '.users[] | select(.role == "owner") | .user_id' "$users_file")"
owner_house="$(get_json "$owner_token" "profiles?select=default_household_id&id=eq.$owner_id" | jq -er '.[0].default_household_id')"
partner_id="$(jq -r '.users[] | select(.role == "partner") | .user_id' "$users_file")"
teen_id="$(jq -r '.users[] | select(.role == "teen") | .user_id' "$users_file")"
viewer_id="$(jq -r '.users[] | select(.role == "viewer") | .user_id' "$users_file")"

invite_and_redeem() {
  local target_token="$1" target_id="$2" role="$3" code member_id
  member_id="$(get_json "$target_token" "household_members?select=id&household_id=eq.$owner_house&user_id=eq.$target_id&deleted_at=is.null&limit=1" | jq -r '.[0].id // empty')"
  if [[ -z "$member_id" ]]; then
    code="$(rpc "$owner_token" create_invite "$(jq -nc --arg h "$owner_house" --arg role "$role" '{p_household:$h,p_role:$role,p_days:7}')" | jq -r '.')"
    rpc "$target_token" redeem_invite "$(jq -nc --arg code "$code" '{p_code:$code}')" >/dev/null
  fi
  patch_json "$target_token" "profiles?id=eq.$target_id" \
    "$(jq -nc --arg household "$owner_house" '{default_household_id:$household}')" >/dev/null
}

invite_and_redeem "$partner_token" "$partner_id" adult
invite_and_redeem "$teen_token" "$teen_id" teen
invite_and_redeem "$viewer_token" "$viewer_id" viewer

account_id="$(get_json "$owner_token" "accounts?select=id&household_id=eq.$owner_house&order=sort_order&limit=1" | jq -er '.[0].id')"
reserve_account_name="Reserva E2E"
reserve_account_name_encoded="$(jq -nr --arg name "$reserve_account_name" '$name | @uri')"
reserve_account_id="$(get_json "$owner_token" "accounts?select=id&household_id=eq.$owner_house&name=eq.$reserve_account_name_encoded&deleted_at=is.null&limit=1" | jq -r '.[0].id // empty')"
if [[ -z "$reserve_account_id" ]]; then
  reserve_account_id="$(cat /proc/sys/kernel/random/uuid)"
  post_json "$owner_token" accounts "$(jq -nc \
    --arg id "$reserve_account_id" --arg h "$owner_house" --arg name "$reserve_account_name" \
    '{id:$id,household_id:$h,owner_id:null,name:$name,type:"savings",institution:"E2E",color:"#6F87A6",icon:"savings",opening_balance_cents:0,include_in_totals:true,visibility:"household",sort_order:1}')" >/dev/null
else
  patch_json "$owner_token" "accounts?id=eq.$reserve_account_id&household_id=eq.$owner_house" \
    '{owner_id:null,visibility:"household",archived_at:null,deleted_at:null}' >/dev/null
fi

owner_member="$(get_json "$owner_token" "household_members?select=id,user_id&household_id=eq.$owner_house&user_id=eq.$owner_id" | jq -er '.[0].id')"
partner_member="$(get_json "$partner_token" "household_members?select=id&household_id=eq.$owner_house&user_id=eq.$partner_id" | jq -er '.[0].id')"
teen_member="$(get_json "$teen_token" "household_members?select=id&household_id=eq.$owner_house&user_id=eq.$teen_id" | jq -er '.[0].id')"
market_category="$(get_json "$owner_token" "categories?select=id&household_id=eq.$owner_house&template_key=eq.food.market" | jq -er '.[0].id')"
salary_category="$(get_json "$owner_token" "categories?select=id&household_id=eq.$owner_house&template_key=eq.salary.clt" | jq -er '.[0].id')"
pet_parent="$(get_json "$owner_token" "categories?select=id&household_id=eq.$owner_house&template_key=eq.family" | jq -er '.[0].id')"

custom_category_name="Pets especiais"
custom_category_name_encoded="$(jq -nr --arg name "$custom_category_name" '$name | @uri')"
custom_category_id="$(get_json "$owner_token" "categories?select=id&household_id=eq.$owner_house&name=eq.$custom_category_name_encoded&kind=eq.expense&deleted_at=is.null&limit=1" | jq -r '.[0].id // empty')"
if [[ -z "$custom_category_id" ]]; then
  custom_category_id="$(cat /proc/sys/kernel/random/uuid)"
  post_json "$owner_token" categories "$(jq -nc \
    --arg id "$custom_category_id" --arg h "$owner_house" --arg parent "$pet_parent" --arg name "$custom_category_name" \
    '{id:$id,household_id:$h,parent_id:$parent,name:$name,kind:"expense",icon:"pets",color:"#6F87A6"}')" >/dev/null
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
known_transaction_descriptions='["Salário principal","Mercado do bairro","Delivery da família","Lanche da escola","Veterinário","Compra com comprovante"]'
transactions='[]'
cleanup_count=0
transaction_rows="$(get_json "$owner_token" "transactions?select=id,description,member_id,kind,amount_cents,category_id,account_id,receipt_id,created_at&household_id=eq.$owner_house&deleted_at=is.null" |
  jq -c --argjson known "$known_transaction_descriptions" '
    map(select(.description as $description | ($known | index($description)) != null))')"

find_transaction_candidates() {
  local description="$1" member="$2" kind="$3" amount="$4" category="$5"
  jq -c --arg description "$description" --arg member "$member" --arg kind "$kind" \
      --arg amount "$amount" --arg category "$category" --arg account "$account_id" '
      map(select(
        .description == $description and
        .member_id == $member and
        .kind == $kind and
        (.amount_cents | tostring) == $amount and
        .category_id == $category and
        .account_id == $account
      )) | sort_by([
        (if (.receipt_id // "") == "" then 1 else 0 end),
        (.created_at // ""),
        .id
      ])' <<<"$transaction_rows"
}

add_transaction() {
  local token="$1" member="$2" kind="$3" amount="$4" description="$5" category="$6" receipt_id="${7:-}"
  local id payload existing_id duplicate_id candidates existing_receipt_id
  candidates="$(find_transaction_candidates "$description" "$member" "$kind" "$amount" "$category")"
  existing_id="$(jq -r '.[0].id // empty' <<<"$candidates")"
  if [[ -n "$existing_id" ]]; then
    while IFS= read -r duplicate_id; do
      [[ -n "$duplicate_id" ]] || continue
      patch_json "$owner_token" "transactions?id=eq.$duplicate_id&household_id=eq.$owner_house&deleted_at=is.null" \
        "$(jq -nc --arg deleted_at "$now" '{deleted_at:$deleted_at}')" >/dev/null
      cleanup_count=$((cleanup_count + 1))
    done < <(jq -r '.[1:][].id' <<<"$candidates")

    existing_receipt_id="$(jq -r '.[0].receipt_id // empty' <<<"$candidates")"
    if [[ -n "$receipt_id" && -z "$existing_receipt_id" ]]; then
      patch_json "$owner_token" "transactions?id=eq.$existing_id&household_id=eq.$owner_house&deleted_at=is.null" \
        "$(jq -nc --arg receipt "$receipt_id" '{receipt_id:$receipt}')" >/dev/null
    fi
    transactions="$(jq -c --arg id "$existing_id" '. + [$id]' <<<"$transactions")"
    return
  fi
  id="$(cat /proc/sys/kernel/random/uuid)"
  payload="$(jq -nc \
    --arg id "$id" --arg h "$owner_house" --arg account "$account_id" \
    --arg member "$member" --arg user "$owner_id" --arg kind "$kind" \
    --argjson amount "$amount" --arg occurred "$now" --arg description "$description" \
    --arg category "$category" --arg receipt "$receipt_id" \
    '{id:$id,household_id:$h,account_id:$account,member_id:$member,created_by:$user,kind:$kind,amount_cents:$amount,occurred_at:$occurred,description:$description,category_id:$category,source:"manual"} + (if $receipt == "" then {} else {receipt_id:$receipt} end)')"
  post_json "$token" transactions "$payload" >/dev/null
  transactions="$(jq -c --arg id "$id" '. + [$id]' <<<"$transactions")"
}

add_transaction "$owner_token" "$owner_member" income 620000 "Salário principal" "$salary_category"
add_transaction "$owner_token" "$owner_member" expense 18490 "Mercado do bairro" "$market_category"
add_transaction "$owner_token" "$partner_member" expense 7490 "Delivery da família" "$market_category"
add_transaction "$owner_token" "$teen_member" expense 2500 "Lanche da escola" "$market_category"
add_transaction "$owner_token" "$owner_member" expense 12990 "Veterinário" "$custom_category_id"

receipt_candidates="$(find_transaction_candidates "Compra com comprovante" "$owner_member" expense 3990 "$market_category")"
receipt_id="$(jq -r '.[0].receipt_id // empty' <<<"$receipt_candidates")"
if [[ -z "$receipt_id" ]]; then
  receipt_id="$(cat /proc/sys/kernel/random/uuid)"
  receipt_path="$owner_house/$receipt_id.png"
  printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' |
    base64 -d >"$root_dir/.e2e/receipt.png"
  curl --silent --show-error --fail-with-body \
    "$SUPABASE_URL/storage/v1/object/receipts/$receipt_path" \
    -X POST \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $owner_token" \
    -H "Content-Type: image/png" \
    --data-binary @"$root_dir/.e2e/receipt.png" >/dev/null
  post_json "$owner_token" receipts "$(jq -nc \
    --arg id "$receipt_id" --arg h "$owner_house" --arg user "$owner_id" --arg path "$receipt_path" \
    '{id:$id,household_id:$h,uploaded_by:$user,storage_path:$path,mime_type:"image/png",byte_size:68,ocr_status:"pending"}')" >/dev/null
fi
add_transaction "$owner_token" "$owner_member" expense 3990 "Compra com comprovante" "$market_category" "$receipt_id"

# RLS: usuário de fora não pode enxergar os lançamentos da família.
outsider_rows="$(get_json "$auditor_token" "transactions?select=id&household_id=eq.$owner_house")"
[[ "$(jq 'length' <<<"$outsider_rows")" -eq 0 ]] || {
  echo "Falha RLS: outsider enxergou a Casa de teste." >&2
  exit 1
}

# RLS: viewer não pode escrever.
viewer_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  "$SUPABASE_URL/rest/v1/categories" -X POST \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $viewer_token" \
  -H "Content-Type: application/json" \
  --data "$(jq -nc --arg id "$(cat /proc/sys/kernel/random/uuid)" --arg h "$owner_house" '{id:$id,household_id:$h,name:"Negada",kind:"expense"}')")"
[[ "$viewer_status" -ge 400 ]] || { echo "Falha RLS: viewer escreveu." >&2; exit 1; }

partner_houses="$(get_json "$partner_token" "households?select=id,name&order=created_at")"
partner_house_count="$(jq 'length' <<<"$partner_houses")"
partner_default_house="$(get_json "$partner_token" "profiles?select=default_household_id&id=eq.$partner_id" | jq -er '.[0].default_household_id')"
partner_accounts="$(get_json "$partner_token" "accounts?select=id,name&household_id=eq.$owner_house&order=sort_order")"
partner_account_count="$(jq 'length' <<<"$partner_accounts")"
[[ "$partner_house_count" -eq 2 ]] || { echo "Falha fixture: partner vê $partner_house_count Casas; esperado 2." >&2; exit 1; }
[[ "$partner_default_house" == "$owner_house" ]] || { echo "Falha fixture: Casa da família não é a padrão do partner." >&2; exit 1; }
[[ "$partner_account_count" -eq 2 ]] || { echo "Falha fixture: partner vê $partner_account_count contas; esperado 2." >&2; exit 1; }

final_fixture_rows="$(get_json "$owner_token" "transactions?select=id,description&household_id=eq.$owner_house&deleted_at=is.null" |
  jq -c --argjson known "$known_transaction_descriptions" '
    map(select(.description as $description | ($known | index($description)) != null))')"
final_transaction_count="$(jq 'length' <<<"$final_fixture_rows")"
expected_transaction_count="$(jq 'length' <<<"$known_transaction_descriptions")"
[[ "$final_transaction_count" -eq "$expected_transaction_count" ]] || {
  echo "Falha fixture: contagem E2E inconsistente." >&2
  exit 1
}
[[ "$(jq -r --argjson known "$known_transaction_descriptions" '
  . as $rows |
  [$known[] | . as $description |
    ($rows | map(select(.description == $description)) | length)] |
  any(.[]; . != 1)' <<<"$final_fixture_rows")" == "false" ]] || {
  echo "Falha fixture: descrições E2E não ficaram únicas." >&2
  exit 1
}
effective_transactions="$(jq -c 'sort_by(.description) | map(.id)' <<<"$final_fixture_rows")"

jq -n \
  --arg household_id "$owner_house" \
  --arg account_id "$account_id" \
  --arg reserve_account_id "$reserve_account_id" \
  --arg owner_member "$owner_member" \
  --arg partner_member "$partner_member" \
  --arg teen_member "$teen_member" \
  --arg custom_category_id "$custom_category_id" \
  --arg receipt_id "$receipt_id" \
  --argjson transactions "$effective_transactions" \
  --argjson transaction_count "$final_transaction_count" \
  --argjson soft_deleted_duplicates "$cleanup_count" \
  --argjson partner_house_count "$partner_house_count" \
  --arg partner_default_house "$partner_default_house" \
  --argjson partner_account_count "$partner_account_count" \
  '{household_id:$household_id,account_id:$account_id,reserve_account_id:$reserve_account_id,members:{owner:$owner_member,partner:$partner_member,teen:$teen_member},custom_category_id:$custom_category_id,receipt_id:$receipt_id,transactions:$transactions,transaction_count:$transaction_count,cleanup:{soft_deleted_duplicates:$soft_deleted_duplicates},verification:{partner_house_count:$partner_house_count,partner_default_household_id:$partner_default_house,partner_account_count:$partner_account_count},rls:{outsider_read:"blocked",viewer_write:"blocked"}}' >"$summary_file"
chmod 600 "$summary_file"

echo "Família E2E configurada: owner + adult + teen + viewer."
echo "Fixtures: $final_transaction_count lançamentos E2E ativos, categoria customizada e recibo."
echo "Cleanup remoto: $cleanup_count duplicata(s) soft-deletada(s); rerun idempotente."
echo "Partner: 2 Casas, Casa da família padrão e 2 contas (incluindo Reserva E2E)."
echo "RLS: leitura externa e escrita de viewer bloqueadas."
