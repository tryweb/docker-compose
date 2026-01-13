# Ref - https://github.com/d3vilh/openvpn-ui/tree/main#openvpn-client-subnets-guest-and-home-users
# Example.
#iptables -A FORWARD -s 10.0.70.88 -d 10.0.70.77 -j DROP
#iptables -A FORWARD -d 10.0.70.77 -s 10.0.70.88 -j DROP