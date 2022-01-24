#!/bin/bash
# Fred DENIS -- 19.01.2022 -- a quick and dirty script to change a password
# dcli -g ~/dbs_group -l root -x change-password.sh to quicky change a password everywhere on an Exadata !
#
P="xxxxxx"
U="root"

echo "${P}" | passwd --stdin "${U}"
