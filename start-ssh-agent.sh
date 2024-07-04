#!bin/bash
sudo sh -c 'export SSH_AUTH_SOCK="'"$SSH_AUTH_SOCK"'"; export SSH_AGENT_PID="'"$SSH_AGENT_PID"'";ssh-add "'"$1"'"'
