#!/bin/bash
INTERFACE="wlp1s0"
# Gera um MAC aleatório e reinicia a interface para aplicar
sudo ip link set dev $INTERFACE down
sudo macchanger -r $INTERFACE
sudo ip link set dev $INTERFACE up
