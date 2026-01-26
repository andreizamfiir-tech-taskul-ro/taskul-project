iptables -I OUTPUT -p tcp --dport 3000 -j DROP
iptables -I OUTPUT -s 127.0.0.1 -p tcp --dport 3000 -j ACCEPT


# Use -D instead of -I for deleting the rule
iptables -D OUTPUT -p tcp --dport 3000 -j DROP
iptables -D OUTPUT -s 127.0.0.1 -p tcp --dport 3000 -j ACCEPT