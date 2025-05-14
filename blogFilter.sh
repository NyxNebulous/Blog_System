#!/bin/bash

# mentioned that script is run for an author's public directory, so author must be given as an argument while running the script

if [ $# -ne 1 ]; then 
    echo "Error: Please enter one author as argument"
    exit 1
fi

author="$1"
author_public="/home/authors/$author/public"

# Check if author public directory exists
if [ ! -d "$author_public" ]; then
    echo "Error: Author public directory $author_public does not exist"
    exit 1
fi

blacklist="/home/mods/$USER/blacklist.txt"


if [ ! -f "$blacklist" ]; then
    cat << EOF > "$blacklist"
shit
bastard
kill
crap
slut
suicide
EOF
    chmod 600 "$blacklist" || {
        echo "Error: Failed to set permissions on blacklist"
        exit 1
    }
    echo "Created blacklist"
fi


for symlink in "$author_public"/*; do
    blog_name=$(basename "$symlink")
    blog_file="/home/authors/$author/blogs/$blog_name"
    
    if [ ! -f "$blog_file" ]; then
        echo "Error: Blog file $blog_file does not exist"
        continue
    fi
    
    total_matches=0
    
    # creating temp file to later on to have control over whether to change the file or not
    temp_file=$(mktemp)

    cp "$blog_file" "$temp_file" || {
        echo "Error: Failed to copy $blog_file to temp file"
        rm -f "$temp_file"
        continue
    }

    while IFS= read -r word; do
        asterisks=$(printf '%*s' ${#word} | tr ' ' '*')
        matches=$(grep -ni "\b$word\b" "$blog_file")
        
        if [ -n "$matches" ]; then
            echo "$matches" | while IFS=: read -r line_no line; do
                echo "Found blacklisted word $word in $blog_name at line $line_no"
            done

            matches_count=$(echo "$matches" | wc -l)
            total_matches=$((total_matches + matches_count))

            sed -i -E "s/\b$word\b/$asterisks/gI" "$temp_file" >/dev/null || {
                echo "Error: Failed to replace word with asterisk"
                rm -f "$temp_file"
                continue
            }
        fi
    done < "$blacklist"

    if [ $total_matches -gt 0 ]; then
        mv "$temp_file" "$blog_file" || {
            echo "Error: Failed to update $blog_file"
            rm -f "$temp_file"
            continue
        }
    else
        rm -f "$temp_file"
    fi

    if [ $total_matches -ge 5 ]; then
        echo "Blog $blog_name is archived due to excessive blacklisted words"
        rm "$symlink" || {
            echo "Error: Failed to remove symlink $symlink"
            continue
        }

        blogs_yaml="/home/authors/$author/blogs.yaml"
        if [ -f "$blogs_yaml" ]; then
            sudo -u $author yq eval -i ".blogs[] | select(.file_name == \"$blog_name\").publish_status = false" "$blogs_yaml" || {
                echo "Error: Failed to update publish_status in $blogs_yaml"
                continue
            }
            sudo -u $author yq eval -i "(.blogs[] | select(.file_name == \"$blog_name\")).mod_comments = \"found $total_matches blacklisted words\"" "$blogs_yaml" || {
                echo "Error: Failed to update mod_comments in $blogs_yaml"
                continue
            }
        else 
            echo "Warning: $blogs_yaml does not exist"
        fi
    fi
done

