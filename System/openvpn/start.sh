#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 快速启动OpenVPN客户端
# @Usage: sudo bash start.sh

openvpn --daemon --cd /etc/openvpn/client --config asustor_include_ca.ovpn --log-append /etc/openvpn/log/openvpn.log
