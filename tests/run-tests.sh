#!/bin/sh
set -ex

d=$(readlink -f "$(dirname $0)")
password=thepassword

rm -rf "$d/slapd-config" "$d/slapd-data"
mkdir "$d/slapd-config" "$d/slapd-data"

module_path='/usr/lib/ldap'
test -d "$module_path" \
	|| module_path='/usr/lib/openldap'

schema_path='/etc/ldap/schema'
test -d "$schema_path" \
	|| module_path='/etc/openldap/schema'


# populate slapd config
slapadd -F "$d/slapd-config" -n0 <<EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcPidFile: $d/slapd.pid

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath: $module_path
olcModuleload: back_bdb.so

include: file://$schema_path/core.ldif
include: file://$schema_path/cosine.ldif
include: file://$schema_path/inetorgperson.ldif
include: file://$schema_path/nis.ldif

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by * none

dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: bdb
olcSuffix: dc=example,dc=invalid
olcDbDirectory: $d/slapd-data
olcDbIndex: objectClass eq
olcAccess: to * by * write
#olcAccess: to * by users write
EOF

# populate slapd data
slapadd -F "$d/slapd-config" -n1 <<EOF
dn: dc=example,dc=invalid
objectClass: top
objectClass: domain

#dn: ou=users,dc=example,dc=invalid
#objectClass: top
#objectClass: organizationalUnit
#ou: users

dn: uid=ldapuser,dc=example,dc=invalid
objectClass: top
objectClass: person
objectClass: organizationalperson
objectClass: inetorgperson
objectClass: posixAccount
cn: My LDAP User
givenName: My
sn: LDAP User
uid: ldapuser
uidNumber: 15549
gidNumber: 15549
homeDirectory: /home/lol
mail: ldapuser@example.invalid
userPassword: $(slappasswd -s "$password")
EOF

slapd -F "$d/slapd-config" -h ldap://localhost:3899/
trap 'kill -TERM $(cat "$d/slapd.pid")' EXIT

${LUA:-lua} tests/test.lua \
	localhost:3899 \
	dc=example,dc=invalid \
	uid=ldapuser,dc=example,dc=invalid \
	"$password"
