#!/usr/bin/env bash
#
# Build for interactive use, i. e. set PATH accordingly if run via cron
#
# To facilitate "virtual remote execution" ;), enter target hostname as $1

uname="`uname -n`"
if [ $# -eq 1 ]; then
  uname="$1"
  (>&2 echo "Using $1 as local hostname")
fi

# Make sure we don't get surprised by I8N ;-)
LANG=C
export LANG

# This is a bit messy. AS206946 bgp host are named CCTLD#.dn42.uu.org
# they get mapped to xx##-names (or, actually, anything except bgp##)
# for the tun-ip.sh-script, as we want to peer with our Freifunk BGP
# hosts as well (which is where tun-ip-sh originates from). Thus, if
# name is ^bgp, we must lookup $name.4830.org to find the ipv4
# tunnelendpoint, but we must use the mapped name for the invocation
# of tun-ip.sh ...
#
# Format of as206946-tunnel.txt is link-spec <space> tunnel-type, e. g.
#
# de3:uk2 gre
# de3:us1 l2tp
# de3:gut1 ovpn

for i in `sed -e 's/ /;/g' <as206813-tunnel.txt | grep ${uname}`
do
  linkspec="`echo $i | cut -d ";" -f 1`"
  TYPE="`echo $i | cut -d ";" -f 2`"
  LHS="`echo ${linkspec} | awk '{split($1, lp, ":"); print lp[1];}'`"
  RHS="`echo ${linkspec} | awk '{split($1, lp, ":"); print lp[2];}'`"
  LHSshort="`echo ${linkspec} | awk '{gsub("-", "", $1); split($1, lp, ":"); print lp[1];}'`"
  RHSshort="`echo ${linkspec} | awk '{gsub("-", "", $1); split($1, lp, ":"); print lp[2];}'`"
  LHTMPNAME="`echo ${linkspec} | cut -d " " -f 1 | sed -f ./as206813-tunnel-mapping.sed | awk '{split($1, lp, ":"); print lp[1];}'`"
  RHTMPNAME="`echo ${linkspec} | cut -d " " -f 1 | sed -f ./as206813-tunnel-mapping.sed | awk '{split($1, lp, ":"); print lp[2];}'`"
  domain="4830.org"
  tunprefix="T"
  if [ "${TYPE}" = "l2tp-eth" ]; then
    tunprefix="E"
  fi
  LHSIP="`host ${LHS}.${domain} | awk '/has address/ {print $NF;}'`"
  RHSIP="`host ${RHS}.${domain} | awk '/has address/ {print $NF;}'`"
  if [ "$LHS" = "$uname" ]; then
    echo "${tunprefix}${RHSshort}:"
    echo "  pub4src: \"$LHSIP\""
    echo "  pub4dst: \"$RHSIP\""
    ./tun-ip.sh $LHTMPNAME:$RHTMPNAME | awk '{gsub("IP", "ip", $1); gsub(":", "src:", $1); printf("  %s \"%s\"\n", $1, $2);}'
    ./tun-ip.sh $RHTMPNAME:$LHTMPNAME | awk '{gsub("IP", "ip", $1); gsub(":", "dst:", $1); printf("  %s \"%s\"\n", $1, $2);}'
    echo "  mode: \"${TYPE}\""
  else
    echo "${tunprefix}${LHSshort}:"
    echo "  pub4src: \"$RHSIP\""
    echo "  pub4dst: \"$LHSIP\""
    ./tun-ip.sh $LHTMPNAME:$RHTMPNAME | awk '{gsub("IP", "ip", $1); gsub(":", "dst:", $1); printf("  %s \"%s\"\n", $1, $2);}'
    ./tun-ip.sh $RHTMPNAME:$LHTMPNAME | awk '{gsub("IP", "ip", $1); gsub(":", "src:", $1); printf("  %s \"%s\"\n", $1, $2);}'
    echo "  mode: \"${TYPE}\""
  fi
  echo
done | sed -e 's%/64%%g'> tunnel.yaml
