#!/bin/bash
#
# Pimarchy Library — Template Engine
#

load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        set -a
        source "$config_file"
        set +a
    else
        log_error "Config file not found: $config_file"
        return 1
    fi
}

# process_template — replace {{VAR}} placeholders with environment values.
# Bounded at 1000 expansions to catch self-referential loops.
process_template() {
    local template_file="$1"
    local output_file="$2"
    local max_iterations=100
    local iteration=0

    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    mkdir -p "$(dirname "$output_file")"

    local content
    content=$(<"$template_file")

    local var_name var_value
    while [[ $content =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        var_name="${BASH_REMATCH[1]}"

        if [ -z "${!var_name+x}" ]; then
            log_warn "Undefined variable in template: $var_name"
            var_value=""
        else
            var_value="${!var_name}"
        fi

        content="${content//\{\{$var_name\}\}/$var_value}"

        iteration=$((iteration + 1))
        if [ $iteration -gt $max_iterations ]; then
            log_error "Too many template variables or infinite loop detected"
            return 1
        fi
    done

    printf '%s\n' "$content" > "$output_file"
    log_success "Generated: $output_file"
}