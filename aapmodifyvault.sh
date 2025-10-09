#!/bin/bash

# Get the directory of the script
parent_dir=$(dirname "$(readlink -f "$0")")

# --- Function to display usage ---
# Moved to the top and made generic for better script structure.
usage() {
    echo "Usage: $0 <org> <env>"
    exit 1
}

# --- Initial Argument Validation ---
# Ensure the two mandatory arguments are provided.
if [[ $# -lt 2 ]]; then
    echo "Error: Missing organization and/or environment arguments."
    echo ""
    usage
fi

org=$1
env=$2
orgs_base_dir="$parent_dir/orgs_vars"

# --- Validate Organization ---
# Check if the organization directory exists before proceeding.
if [[ ! -d "$orgs_base_dir/$org" ]]; then
    echo "Error: Organization '$org' not found."
    echo ""
    # List available orgs to help the user.
    available_orgs=$(find "$orgs_base_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f|" | sed 's/|$//')
    echo "Available organizations: {$available_orgs}"
    exit 1
fi

# --- Validate Environment ---
env_dir="$orgs_base_dir/$org/env"
# Check if the environment exists and is not the 'common' directory.
if [[ ! -d "$env_dir/$env" ]]; then
    echo "Error: Environment '$env' not found or is invalid for organization '$org'."
    echo ""
    # List available environments for the given organization.
    available_envs=$(find "$env_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f|" | sed 's/|$//')
    echo "Available environments for '$org': {$available_envs}"
    exit 1
fi

# Change to the playbooks directory.
cd "$parent_dir" || { echo "Failed to change directory to $parent_dir"; exit 1; }

# --- Define the file to edit and execute the command ---
file_to_edit="${env_dir}/${env}/vault.yml"

echo "Opening vault file: $file_to_edit"
ansible-vault edit "$file_to_edit"