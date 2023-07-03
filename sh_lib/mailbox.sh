function camp_mailbox() {
  while True; do
    collect_mail
    sleep $(bc <<< "$(rapid_tap_delay) * 20 + $(rapid_tap_delay)")
  done
}
