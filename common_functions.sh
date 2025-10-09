#!/bin/bash

# This function contains all the common logic for argument parsing and validation.
# It sets the following variables for the calling script to use:
# - org
# - env
# - casc_aap_version
# - tags
# - execution_environment

initialize_and_validate() {
    local script_type=$1
    shift # Remove script_type from the arguments list

    # --- Initial Argument Validation ---
    if [[ $# -lt 2 ]]; then
        echo "Error: Missing organization and/or environment arguments."
        echo ""
        usage # Calls the usage() function defined in the parent script
    fi

    org=$1
    env=$2
    local orgs_base_dir="$parent_dir/orgs_vars"

    # --- Validate Organization ---
    if [[ ! -d "$orgs_base_dir/$org" ]]; then
        echo "Error: Organization '$org' not found."
        echo ""
        local available_orgs
        available_orgs=$(find "$orgs_base_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f|" | sed 's/|$//')
        echo "Available organizations: {$available_orgs}"
        exit 1
    fi

    # --- Validate Environment ---
    local env_dir="$orgs_base_dir/$org/env"
    if [[ ! -d "$env_dir/$env" ]] || [[ "$env" == "common" ]]; then
        echo "Error: Environment '$env' not found or is invalid for organization '$org'."
        echo ""
        local available_envs
        available_envs=$(find "$env_dir" -mindepth 1 -maxdepth 1 -type d -not -name "common" -printf "%f|" | sed 's/|$//')
        echo "Available environments for '$org': {$available_envs}"
        exit 1
    fi

    # Get the version *before* parsing tags for contextual usage messages.
    casc_aap_version="$(yq '.casc_aap_version' "$env_dir/$env/vars.yml")"

    # --- Argument Parsing ---
    shift 2 # Remove org and env from the argument list
    tags=""
    local all=false

    if [[ -z "$1" ]]; then
        echo "Error: Missing option [-a|--all] or [-t|--tags]."
        usage "$casc_aap_version"
    fi

    case $1 in
        -a|--all)
            all=true
            ;;
        -t|--tags)
            if [ -n "$2" ]; then
                tags="$2"
            else
                echo "Error: --tags requires an argument."
                usage "$casc_aap_version"
            fi
            ;;
        *)
            echo "Unknown option: $1"
            usage "$casc_aap_version"
            ;;
    esac

    # --- Define the single source of truth for the script vars file ---
    local script_vars_file="$script_vars_dir/$casc_aap_version/vars.yml"
    if [[ ! -f "$script_vars_file" ]]; then
        echo "Error: Script variables file not found at $script_vars_file"
        exit 1
    fi

    # --- Tag Validation Section ---
    if [ -n "$tags" ]; then
        # Build the yq query keys dynamically based on the script type
        local category_tags_key="aap${script_type}_category_tags"
        local specific_tags_key="aap${script_type}_specific_tags"

        declare -A valid_tags_map
        while IFS= read -r tag; do
            valid_tags_map["$tag"]=1
        done < <(yq ".${category_tags_key}[], .${specific_tags_key}[][]" "$script_vars_file" 2>/dev/null)

        local invalid_tags=()
        local user_tags_arr=()
        IFS=',' read -ra user_tags_arr <<< "$tags"
        for user_tag in "${user_tags_arr[@]}"; do
            local user_tag_trimmed
            user_tag_trimmed=$(echo "$user_tag" | xargs) # Trim whitespace
            if [[ -z "${valid_tags_map[$user_tag_trimmed]}" ]]; then
                invalid_tags+=("$user_tag_trimmed")
            fi
        done

        if [ ${#invalid_tags[@]} -gt 0 ]; then
            echo "Error: Invalid tag(s) provided: ${invalid_tags[*]}"
            echo "Please use one of the supported tags for AAP version $casc_aap_version."
            echo ""
            usage "$casc_aap_version"
        fi
        echo "✅ Tags validated successfully."
    fi

    # --- Get Execution Environment ---
    execution_environment="$(yq '.execution_environment' "$script_vars_file")"
}