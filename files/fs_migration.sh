#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
# This script is used to migrate Forpsi default CentOS7 FS layout
# to LVM.
# Author: hajnej
# Version: alpha
find_root_device() {
  read -a line < /proc/cmdline
  for stanza in ${line[@]}; do
    if [ "${stanza%%=*}" == 'root' ]; then
      root_dev="${stanza##root=}"
      break
    fi
  done
}

get_rootfs_extents() {
  mount | grep -q /sysroot
  if [ $? -ne 0 ]; then
    find_root_device
    mount $root_dev /sysroot 2> /dev/null
  fi
  vg_extent_size=$(lvm vgs --nohead -o vg_extent_size --unit=m)
  vg_extent_size="${vg_extent_size%%.*}"
  size=$(df -B${vg_extent_size}m --output=size /sysroot)
  # Output is number of PE extents. Get get rid of first field
  size="${size##* }"
  umount /sysroot
}

shrink_rootfs() {
  find_root_device
  mount | grep -q /sysroot
  if [ $? -eq 0 ]; then
    umount /sysroot
  fi
  e2fsck -f -y "$root_dev"
  resize2fs -M "$root_dev"
  get_rootfs_extents
  size=$((size*2))
  echo "Reducing $root_dev LVM size to $size k"
  lvm lvreduce -f --config 'global {locking_type=1}' -l ${size} $root_dev
  e2fsck -f -y "$root_dev"
  resize2fs -f "$root_dev"
}

shrink_rootfs
exit 0
