#!/bin/bash

echo "_____[1] Creating groups _____"
groups=(g_user g_author g_mod g_admin)

for group in "${groups[@]}"; do
    groupadd "$group" 2>/dev/null || echo "Line 7: Group '$group' already exists or couldn't be created."
done

echo "_____[2] Creating base directories _____"
mkdir -p /home/users /home/authors /home/mods /home/admin || echo "Line 12: Failed to create base directories."

echo "_____[3] Creating users _____"
user=($(yq e '.users[].name' users.yaml))
user_name=($(yq e '.users[].username' users.yaml))

for ((i = 0; i < ${#user[@]}; i++)); do
    uname="${user_name[i]}"
    if ! id "$uname" &>/dev/null; then
        mkdir -p /home/users/"$uname"/all_blogs || echo "Line 20: Failed to create all_blogs for $uname"
        useradd -m -d /home/users/"$uname" -g g_user "$uname" 2>/dev/null || echo "Line 21: Failed to create user $uname"
        chown -R "$uname":g_user /home/users/"$uname"/all_blogs || echo "Line 22: Failed to chown all_blogs for $uname"
        chmod -R 700 /home/users/"$uname"/all_blogs || echo "Line 23: Failed to chmod all_blogs for $uname"
        echo "Line 24: User $uname created and configured"
    else
        echo "Line 26: User $uname already exists"
    fi
done

echo "_____[4] Creating authors _____"
auth=($(yq e '.authors[].name' users.yaml))
auth_name=($(yq e '.authors[].username' users.yaml))

for ((i = 0; i < ${#auth[@]}; i++)); do
    aname="${auth_name[i]}"
    if ! id "$aname" &>/dev/null; then
        mkdir -p /home/authors/"$aname"/{blogs,public} || echo "Line 35: Failed to create blogs/public for $aname"
        useradd -m -d /home/authors/"$aname" -g g_author "$aname" 2>/dev/null || echo "Line 36: Failed to create author $aname"
        chown -R "$aname":g_author /home/authors/"$aname" || echo "Line 37: Failed to chown author $aname"
        chmod -R 700 /home/authors/"$aname" || echo "Line 38: Failed to chmod author $aname"
        chmod -R 755 /home/authors/"$aname"/public || echo "Line 39: Failed to chmod public for $aname"
        echo "Line 40: Author $aname created"
    else
        echo "Line 42: Author $aname already exists"
    fi
done

echo "_____[5] Linking blogs to users _____"
for ((i = 0; i < ${#user[@]}; i++)); do
    for ((j = 0; j < ${#auth[@]}; j++)); do
        ln -sf /home/authors/"${auth_name[j]}"/public /home/users/"${user_name[i]}"/all_blogs/"${auth_name[j]}" 2>/dev/null \
        || echo "Line 48: Failed to link ${auth_name[j]}'s public to ${user_name[i]}'s all_blogs"
    done
done

echo "_____[6] Creating moderators _____"
mod=($(yq e '.mods[].name' users.yaml))
mod_name=($(yq e '.mods[].username' users.yaml))

for ((i = 0; i < ${#mod[@]}; i++)); do
    mname="${mod_name[i]}"
    if ! id "$mname" &>/dev/null; then
        mkdir -p /home/mods/"$mname"
        useradd -m -d /home/mods/"$mname" -g g_mod "$mname" 2>/dev/null || echo "Line 59: Failed to create mod $mname"
        chown -R "$mname":g_mod /home/mods/"$mname" || echo "Line 60: Failed to chown mod $mname"
        chmod -R 700 /home/mods/"$mname" || echo "Line 61: Failed to chmod mod $mname"
        echo "Line 62: Moderator $mname created"
    else
        echo "Line 64: Mod $mname already exists"
    fi
done

echo "_____[7] Creating admins _____"
admin=($(yq e '.admins[].name' users.yaml))
admin_name=($(yq e '.admins[].username' users.yaml))

for ((i = 0; i < ${#admin[@]}; i++)); do
    aname="${admin_name[i]}"
    if ! id "$aname" &>/dev/null; then
        mkdir -p /home/admin/"$aname"
        useradd -m -d /home/admin/"$aname" -g g_admin "$aname" 2>/dev/null || echo "Line 74: Failed to create admin $aname"
        chown -R "$aname":g_admin /home/admin/"$aname" || echo "Line 75: Failed to chown admin $aname"
        chmod -R 700 /home/admin/"$aname" || echo "Line 76: Failed to chmod admin $aname"
        setfacl -R -m u:$aname:rwx /home/{authors,users,mods} || echo "Line 77: Failed to set ACL for $aname"
        echo "Line 78: Admin $aname created"
    else
        echo "Line 80: Admin $aname already exists"
    fi
done

echo "_____[8] Setting mod permissions for authors _____"
for mod in $(yq e '.mods[].username' users.yaml); do
    authors=$(yq e ".mods[] | select(.username == \"$mod\") | .authors[]" users.yaml)
    for author in $authors; do
        setfacl -m u:$mod:rw /home/authors/$author/public || echo "Line 86: Failed ACL for mod $mod on $author"
    done
done

echo "_____[9] Setting mod permissions for users _____"
for user in $(awk -F":" '$3 > 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    if [[ $user == [a-z]* && $user != "$(whoami)" ]] && ! yq e '.users[].username' users.yaml | grep -q "$user"; then
        passwd -l "$user"
    fi
done

echo "_____Script finished!____"

