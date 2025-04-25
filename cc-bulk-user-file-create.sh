#!/bin/bash
set -x

#######################################################################
#  run this on the CycleCloud VM
#######################################################################

now=$(TZ=America/New_York date +"%Y%m%d_%I%M")

file="$HOME/user-records-${now}.txt"

# Create the associative array that contains the user name and public key
declare -A userkeys
userkeys=( \
  ["user101"]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWm4tnf23mzb6jwmZhN1x8MiSMKF1RbfjaMhK+c0l/hpIgRuOJWPqJf+mEuM2br5jan+AHU65NAhsszodmKA7HRKPHcyS3OzT694kJqCisKC8/5Y8RlzCXUvSOdu6bWgyccnv4b5k/xRhrv2GE5bC51dC+4mH1vBzSIzVbIoWzvO9jl90ZEG2Bygk4ypB7oBnvH1kyTQ5TdY6CgX5cjdBJd+blVq13kY7kBo6aJia9nus1zwKluWu1cVlipTOeIU9Nk4gmTckEcutojTrk/9J55aOjJs8axAVG1rrhqvHYMnVTmLlCRiBANBaYIFBjvYvF0dKjvaFKCDVbM4doDF5KGGHqJrfKOyIAW0YhLPggq6trMJAWOWyMu0J5qqgyH8bc31OV7y9m2B2USZvzu27WZmxya4Me+0YOQDzcT0bJBw5Sp1TII3XhBOgNgP+/uQVWxMuXOktu3J7nbfhV82u+K9YXByH24bXKYQo2KxZm4KY0kBIq932m+UupSIsYo8U=" \
  ["user102"]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWm4tnf23mzb6jwmZhN1x8MiSMKF1RbfjaMhK+c0l/hpIgRuOJWPqJf+mEuM2br5jan+AHU65NAhsszodmKA7HRKPHcyS3OzT694kJqCisKC8/5Y8RlzCXUvSOdu6bWgyccnv4b5k/xRhrv2GE5bC51dC+4mH1vBzSIzVbIoWzvO9jl90ZEG2Bygk4ypB7oBnvH1kyTQ5TdY6CgX5cjdBJd+blVq13kY7kBo6aJia9nus1zwKluWu1cVlipTOeIU9Nk4gmTckEcutojTrk/9J55aOjJs8axAVG1rrhqvHYMnVTmLlCRiBANBaYIFBjvYvF0dKjvaFKCDVbM4doDF5KGGHqJrfKOyIAW0YhLPggq6trMJAWOWyMu0J5qqgyH8bc31OV7y9m2B2USZvzu27WZmxya4Me+0YOQDzcT0bJBw5Sp1TII3XhBOgNgP+/uQVWxMuXOktu3J7nbfhV82u+K9YXByH24bXKYQo2KxZm4KY0kBIq932m+UupSIsYo8U=" \
  ["user103"]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWm4tnf23mzb6jwmZhN1x8MiSMKF1RbfjaMhK+c0l/hpIgRuOJWPqJf+mEuM2br5jan+AHU65NAhsszodmKA7HRKPHcyS3OzT694kJqCisKC8/5Y8RlzCXUvSOdu6bWgyccnv4b5k/xRhrv2GE5bC51dC+4mH1vBzSIzVbIoWzvO9jl90ZEG2Bygk4ypB7oBnvH1kyTQ5TdY6CgX5cjdBJd+blVq13kY7kBo6aJia9nus1zwKluWu1cVlipTOeIU9Nk4gmTckEcutojTrk/9J55aOjJs8axAVG1rrhqvHYMnVTmLlCRiBANBaYIFBjvYvF0dKjvaFKCDVbM4doDF5KGGHqJrfKOyIAW0YhLPggq6trMJAWOWyMu0J5qqgyH8bc31OV7y9m2B2USZvzu27WZmxya4Me+0YOQDzcT0bJBw5Sp1TII3XhBOgNgP+/uQVWxMuXOktu3J7nbfhV82u+K9YXByH24bXKYQo2KxZm4KY0kBIq932m+UupSIsYo8U=" \
  )

# set the starting UID value for users; to be incremented by 1 for each new user
uid=22200

for user in "${!userkeys[@]}"; do
   cat <<EOF >>$file
AdType = "AuthenticatedUser"
Name = "${user}"
###  If using CycleCloud internal user database for auth, uncomment line 28 and comment out line 29
#Authentication = "internal"
Authentication = "active_directory"
Roles = {"User"}
UID = ${uid}
Superuser = false
Description = "added via bulk add file ${file}"

CommonName: "public"
PublicKey = "${userkeys[$user]}"
AdType = "Credential"
Owner =  "${user}"
CredentialType = "PublicKey"
Name = "${user}/public"

EOF
  ((uid+=1))
done

sudo cp $file /opt/cycle_server/config/data
