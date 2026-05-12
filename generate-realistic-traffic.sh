#!/usr/bin/env bash
set -u

BASE_URL="${1:-http://localhost:3000}"
DELAY_SECONDS="${DELAY_SECONDS:-1}"

USERS=(
  "student.alice@campushub.edu"
  "student.ben@campushub.edu"
  "prof.chen@campushub.edu"
  "research.admin@campushub.edu"
  "security.analyst@campushub.edu"
)

IPS=(
  "203.0.113.10"
  "203.0.113.24"
  "198.51.100.7"
  "198.51.100.81"
  "192.0.2.44"
  "45.155.205.233"
  "185.220.101.42"
)

UAS=(
  "Mozilla/5.0 CampusHubStudentPortal/1.0"
  "Mozilla/5.0 Chrome/124.0"
  "Mozilla/5.0 Safari/605.1.15"
  "curl/8.1.2"
  "sqlmap/1.7.2"
)

normal_paths=(
  "/api/health"
  "/api/students"
  "/api/courses"
  "/api/research-grants"
)

attack_paths=(
  "/api/students/search?q=%27%20OR%201%3D1--"
  "/api/feedback?message=%3Cscript%3Ealert(document.cookie)%3C%2Fscript%3E"
  "/api/files?name=../../package.json"
  "/api/admin/ping?host=127.0.0.1%3Bwhoami"
  "/api/admin/users"
)

pick() {
  local array_name="$1[@]"
  local arr=("${!array_name}")
  echo "${arr[$RANDOM % ${#arr[@]}]}"
}

send_request() {
  local path="$1"
  local user="$2"
  local ip="$3"
  local ua="$4"
  local label="$5"

  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Forwarded-For: $ip" \
    -H "X-Real-IP: $ip" \
    -H "X-Demo-User: $user" \
    -H "User-Agent: $ua" \
    -H "Accept: application/json" \
    "$BASE_URL$path")

  printf "[%s] %-8s %-28s %-15s %s %s\n" \
    "$(date '+%H:%M:%S')" "$status" "$user" "$ip" "$label" "$path"
}

echo "Generating realistic CampusHub demo traffic against: $BASE_URL"
echo "Set DELAY_SECONDS=0.2 for faster traffic, e.g. DELAY_SECONDS=0.2 ./generate-realistic-traffic.sh"
echo "Press Ctrl+C to stop"
echo

while true; do
  for i in {1..8}; do
    user="$(pick USERS)"
    ip="$(pick IPS)"
    ua="$(pick UAS)"

    if (( RANDOM % 100 < 70 )); then
      path="$(pick normal_paths)"
      send_request "$path" "$user" "$ip" "$ua" "normal"
    else
      path="$(pick attack_paths)"
      send_request "$path" "$user" "$ip" "$ua" "attack"
    fi

    sleep "$DELAY_SECONDS"
  done

  echo "--- burst attack ---"
  attacker_ip="$(pick IPS)"
  attacker_ua="sqlmap/1.7.2"

  for path in "${attack_paths[@]}"; do
    send_request "$path" "unknown.external@campushub.edu" "$attacker_ip" "$attacker_ua" "burst"
    sleep 0.3
  done

  echo
done
