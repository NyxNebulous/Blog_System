#!/bin/bash

if ! groups | grep -q g_author; then
    echo "Error: Only authors can run this script"
    exit 1
fi

HOME_DIR="/home/authors/$USER"
BLOGS_DIR="$HOME_DIR/blogs"
PUBLIC_DIR="$HOME_DIR/public"
BLOGS_YAML="$HOME_DIR/blogs.yaml"

for dir in "$BLOGS_DIR" "$PUBLIC_DIR"; do
    if [ ! -d "$dir" ]; then
        echo "Error: Directory $dir does not exist"
        exit 1
    fi
done

if [ ! -f "$BLOGS_YAML" ]; then
    echo "blogs: []" > "$BLOGS_YAML" || {
        echo "Error: Failed to create $BLOGS_YAML"
        exit 1
    }
    chown "$USER:g_author" "$BLOGS_YAML" || {
        echo "Error: Failed to set ownership of $BLOGS_YAML"
        exit 1
    }
    chmod 600 "$BLOGS_YAML" || {
        echo "Error: Failed to set permissions of $BLOGS_YAML"
        exit 1
    }
    echo "blogs.yaml created"
fi

selPref() {
    while true; do
        cat << EOF
categories:
    1: Sports
    2: Cinema
    3: Technology
    4: Travel
    5: Food
    6: Lifestyle
    7: Finance
EOF
        read -p "Enter category preference (eg. 4,1,2): " pref
        if echo "$pref" | grep -qE '^[1-7](,[1-7])*$'; then
            echo "$pref"
            return 0
        else
            echo "Error: Invalid category format."
        fi
    done
}

publish() {
    local filename="$1"
    if [ ! -f "$BLOGS_DIR/$filename" ]; then
        echo "Error: Blog $filename does not exist in $BLOGS_DIR"
        exit 1
    fi
    local pref
    pref=$(selPref) 
    yq eval -i ".blogs += [{\"file_name\": \"$filename\", \"publish_status\": true, \"cat_order\": [$pref]}]" "$BLOGS_YAML" || {
        echo "Error: Failed to update $BLOGS_YAML"
        exit 1
    }
    ln -sf "$BLOGS_DIR/$filename" "$PUBLIC_DIR/$filename" || {
        echo "Error: Failed to create symlink for $filename"
        exit 1
    }
    chown "$USER:g_user" "$BLOGS_DIR/$filename" || {
        echo "Error: Failed to set ownership of $filename"
        exit 1
    }
    chmod 640 "$BLOGS_DIR/$filename" || {
        echo "Error: Failed to set permissions of $filename"
        exit 1
    }
    echo "Blog $filename published successfully"
}

archive() {
    local filename="$1"
    if [ ! -f "$BLOGS_DIR/$filename" ]; then
        echo "Error: Blog $filename does not exist in $BLOGS_DIR"
        exit 1
    fi
    if [ -L "$PUBLIC_DIR/$filename" ]; then
        rm "$PUBLIC_DIR/$filename" || {
            echo "Error: Failed to remove symlink for $filename"
            exit 1
        }
    else
        echo "Warning: Symlink $PUBLIC_DIR/$filename does not exist"
    fi
    chmod 600 "$BLOGS_DIR/$filename" || {
        echo "Error: Failed to set permissions of $filename"
        exit 1
    }
    yq eval -i "(.blogs[] | select(.file_name == \"$filename\")).publish_status = false" "$BLOGS_YAML" || {
        echo "Error: Failed to update $BLOGS_YAML"
        exit 1
    }
    echo "Blog $filename archived successfully"
}

delete() {
    local filename="$1"
    if [ ! -f "$BLOGS_DIR/$filename" ]; then
        echo "Error: Blog $filename does not exist in $BLOGS_DIR"
        exit 1
    fi
    if [ -L "$PUBLIC_DIR/$filename" ]; then
        rm "$PUBLIC_DIR/$filename" || {
            echo "Error: Failed to remove symlink for $filename"
            exit 1
        }
    fi
    rm "$BLOGS_DIR/$filename" || {
        echo "Error: Failed to delete $filename"
        exit 1
    }
    yq eval -i "del(.blogs[] | select(.file_name == \"$filename\"))" "$BLOGS_YAML" || {
        echo "Error: Failed to update $BLOGS_YAML"
        exit 1
    }
    echo "Blog $filename deleted successfully"
}

edit() {
    local filename="$1"
    if ! yq eval ".blogs[] | select(.file_name == \"$filename\")" "$BLOGS_YAML" > /dev/null; then
        echo "Error: Blog $filename not found in $BLOGS_YAML"
        exit 1
    fi
    local pref
    pref=$(selPref) 
    yq eval -i "(.blogs[] | select(.file_name == \"$filename\")).cat_order = [$pref]" "$BLOGS_YAML" || {
        echo "Error: Failed to update $BLOGS_YAML"
        exit 1
    }
    echo "Categories for $filename updated successfully"
}

while getopts "p:a:d:e:" option; do
	case $option in
		p) publish "$OPTARG";;
		a) archive "$OPTARG";;
		d) delete "$OPTARG";;
		e) edit "$OPTARG";;
		\?) echo "Invalid option";;
	esac
done
