#!/bin/bash

# Flatten everything in the contracts directory and its subdirectories
# Then print the names of all contracts and libraries found
# This can be useful when checking if a certain contract or library is used in the project
# For example when reviewing output of yarn audit

# If invoked by the package script, the flattened dir will be deleted. If you want to view the flattened files, invoke this script directly.

# Ensure the flattened directory exists
mkdir -p flattened

# Function to process a file and print contract/library names
process_file() {
    local file=$1
    
    # Find and print contract names (including abstract)
    grep "^abstract contract \|^contract " "$file" | sed 's/^abstract contract \([^ {]*\).*/Abstract Contract: \1/; s/^contract \([^ {]*\).*/Contract: \1/' | sort -u
    
    # Find and print library names
    grep "^library " "$file" | sed 's/^library \([^ {]*\).*/Library: \1/' | sort -u
}

# Recursively find all .sol files in the contracts directory and its subdirectories
find contracts -name "*.sol" | while read -r file; do
    # Extract the relative path and filename
    rel_path=${file#contracts/}
    dir_path=$(dirname "$rel_path")
    
    # Create the corresponding directory structure in flattened/
    mkdir -p "flattened/$dir_path"
    
    # Create the flattened file path
    flattened_file="flattened/${rel_path%.sol}.flattened.sol"
    
    # Run the forge flatten command (suppressing output)
    forge flatten --output "$flattened_file" "$file" > /dev/null 2>&1
    
    # Process the flattened file
    process_file "$flattened_file"
done | sort -u
