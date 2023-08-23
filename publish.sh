#!/bin/bash

# Reads the local .TAG file with the previous TAG value, if any
# Prompts the user whether to use the same TAG or update it
# If TAG was updated, then first update the docker-compose.*.yml,
# deployment/deployment.*.yml and CHANGELOG.md files
# Then build the container, tag it with :latest and with the TAG, 
# then push the images to ccie-gitlab

if [ -f .TAG ]; then
    saved_tag=$(cat .TAG)
    read -p "The saved TAG is $saved_tag. Do you want to use it? [Y/n] " use_saved_tag
    if [[ $use_saved_tag =~ ^[Nn]$ ]]; then
        read -p "Enter the new value of TAG: " TAG
        echo $TAG > .TAG
    else
        TAG=$saved_tag
    fi
else
    read -p "Enter the value of TAG: " TAG
    echo $TAG > .TAG
fi

if [ "$TAG" != "$saved_tag" ]; then
    read -p "The TAG has changed. Do you want to update the docker-compose.*.yml, deployment/deployment.*.yml and CHANGELOG.md files? [Y/n] " update_files
    if [[ $update_files =~ ^[Nn]$ ]]; then
        echo "Skipping update of docker-compose.*.yml, deployment/deployment.*.yml and CHANGELOG.md files"
    else
        sed -i '' "s/\(api_tag: \).*/\1\"$TAG\"/" docker-compose.yml
        sed -i '' "s/\(api_tag: \).*/\1\"$TAG\"/" docker-compose.debug.yml
        sed -i "s/\(-name: api_tag\)\n[[:blank:]]*value: \".*\"/\1\n  value: \"$TAG\"/" deployment/deployment-events-player.yml
        sed -i '' "/## CURRENT_CHANGES/a\\
\\
- \\
\\
## $TAG\\
" CHANGELOG.md
        echo "Updated docker-compose.yaml and CHANGELOG.md files"
    fi
fi

docker build -t cloudevent-player:latest .
docker tag cloudevent-player:latest cloudevent-player:$TAG

# PUSH TO DMZ
docker login $REGISTRY
docker tag cloudevent-player:latest $REGISTRY_URL/$REGISTRY_PATH/cloudevent-player:$TAG
docker tag cloudevent-player:latest $REGISTRY_URL/$REGISTRY_PATH/cloudevent-player:latest
docker push $REGISTRY_URL/$REGISTRY_PATH/cloudevent-player:$TAG
docker push $REGISTRY_URL/$REGISTRY_PATH/cloudevent-player:latest
