#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

run=/opt/vyatta/bin/vyatta-op-cmd-wrapper

interfaces_output=$($run show interfaces)

# Funzione per estrarre le informazioni delle interfacce VLAN LAN
extract_interfaces() {
  lan_interface=$(echo "$interfaces_output" | awk '$0 ~ /LAN/ {print $1}')
  echo "$interfaces_output" | awk -v lan_interface="$lan_interface" '
    NR > 3 && $1 ~ /^'"$lan_interface"'\.?[0-9]*$/ {
      split($2, ip, "/");
      print $1, ip[1];
    }'
}

# Variabili
rule_id=1

# Generare configurazioni NAT per ogni interfaccia VLAN LAN
generate_nat_rules() {
  configure
  while read -r interface ip; do
    if [ "$ip" != "-" ]; then
      dns_server_ip="$ip"
      set service nat rule $rule_id description "Redirect DNS requests"
      set service nat rule $rule_id destination port "53"
      set service nat rule $rule_id source address "!$dns_server_ip/32"
      set service nat rule $rule_id inbound-interface "$interface"
      set service nat rule $rule_id inside-address address "$dns_server_ip"
      set service nat rule $rule_id inside-address port "53"
      set service nat rule $rule_id log "enable"
      set service nat rule $rule_id protocol "tcp_udp"
      set service nat rule $rule_id type "destination"
      rule_id=$((rule_id + 1))
    fi
  done
  commit
  save
  exit
}

# Esegui le funzioni
interfaces=$(extract_interfaces)
echo $interfaces
generate_nat_rules <<< "$interfaces"
