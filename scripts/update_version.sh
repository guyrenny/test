#!/bin/bash
version=$1

# break down the version number into it's components
regex="([0-9]+).([0-9]+).([0-9]+)"
if [[ $version =~ $regex ]]; then
old_version="${BASH_REMATCH[3]}"
fi

# check paramater to see which number to increment
new_version=$(echo $old_version+1 | bc)


# echo the new version number
echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$new_version"