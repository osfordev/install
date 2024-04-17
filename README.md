# Installation

## Check List (2024-04-17)

- [ ] Create disk layout by call `01-disk-layout-xxx.sh`
- [ ] Init registry

## Disk Layout

### Server

Number of LUKS volumes are server specific

```text
sda
├─sda1
  └─ md0
```

### Workstation Laptop (Secured)

```text
sda
├─sda1
└─sda2
  ├─vg0-images
  ├─vg0-luks--swap
  ├─vg0-luks--registry
  ├─vg0-luks--home
  └─vg0-system
```

## Registry

```shell
#
# Boot by Gentoo Minimal
#

# See for rid value in https://gitea.zxteam.net/orgs/zxteam/src/branch/deployment-openldap-master#openldap-slaves
#
#
LDAP_RID=xxx

LDAP_PWD=xxxxxxxx

mkdir --mode=755 /mnt/registry
vgchange -ay vg0
cryptsetup luksOpen /dev/vg0/luks-registry uncrypted-registry
mount /dev/mapper/uncrypted-registry /mnt/registry/
mkdir --mode=755 /mnt/registry/v1

# LDAP
cat <<EOF > /mnt/registry/v1/openldap.inc
syncrepl rid=${LDAP_RID}
  provider=ldaps://ldap2024.zxteam.net:636
  type=refreshOnly
  interval=00:03:00:00
  retry="5 5 300 5"
  timeout=3
  searchbase="dc=zxteam,dc=net"
  scope=sub
  schemachecking=on
  bindmethod=simple
  binddn="uid=2024,ou=server,ou=replicaaccount,dc=zxteam,dc=net"
  credentials="${LDAP_PWD}"
EOF
chown 439:439 /mnt/registry/v1/openldap.inc
chmod 600 /mnt/registry/v1/openldap.inc

# MAC (optional)
echo "d8:9d:67:95:32:56" > /mnt/registry/v1/mac.eth0
chown 0:0 /mnt/registry/v1/mac.eth0
chmod 644 /mnt/registry/v1/mac.eth0

umount /mnt/registry
cryptsetup luksClose /dev/mapper/uncrypted-registry
vgchange -an vg0
```
