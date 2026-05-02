#!/bin/bash

# --- CONFIGURATION ---
export CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" >/dev/null 2>&1 && pwd )"
BASE_DIR="$CURRENT_DIR"
REPOS_ROOT="$BASE_DIR/repos"
EXTERNAL_REPOS_DIR="$REPOS_ROOT/external-repos"
CUSTOM_REPOS_DIR="$REPOS_ROOT/custom-repos"
CONFIG_FILE="$REPOS_ROOT/config.json"
AGENTS_TARGET="$BASE_DIR/artifacts/synced-items/agents"
SKILLS_TARGET="$BASE_DIR/artifacts/synced-items/skills"

# --- ARGUMENT PARSING ---
DRY_RUN=false
[[ "$1" == "--dry-run" || "$1" == "-d" ]] && DRY_RUN=true && echo "⚠️  DRY RUN MODE"

mkdir -p "$AGENTS_TARGET" "$SKILLS_TARGET" "$EXTERNAL_REPOS_DIR" "$CUSTOM_REPOS_DIR"

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq is required. Install with: brew install jq"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "❌ git is required. Install Git and ensure it is on PATH"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Missing config file: $CONFIG_FILE"
    exit 1
fi

# --- URL/PATH HELPERS ---
normalize_external_slug() {
    local repo_url="$1"
    local cleaned

    # Support HTTPS and SSH-style Git URLs.
    cleaned="${repo_url%.git}"

    if [[ "$cleaned" =~ ^https?://[^/]+/([^/]+)/([^/]+)(/.*)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$cleaned" =~ ^ssh://git@[^/]+/([^/]+)/([^/]+)(/.*)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$cleaned" =~ ^git@[^:]+:([^/]+)/([^/]+)(/.*)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$cleaned" =~ ^([^/]+)/([^/]+)$ ]]; then
        # Also allow direct org/repo entries.
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo ""
    fi
}

repo_id_for_item() {
    local source_root="$1"
    local relative_path="$2"
    local first second

    first="$(echo "$relative_path" | cut -d/ -f1)"

    if [[ "$source_root" == "$EXTERNAL_REPOS_DIR" ]]; then
        second="$(echo "$relative_path" | cut -d/ -f2)"

        # Preferred layout: external-repos/<org>/<repo>/...
        if [[ -n "$first" && -n "$second" && -d "$source_root/$first/$second/.git" ]]; then
            echo "$first/$second"
            return
        fi

        # Backward compatibility: external-repos/<repo>/...
        if [[ -n "$first" && -d "$source_root/$first/.git" ]]; then
            echo "$first"
            return
        fi
    fi

    echo "$first"
}

# --- EXTERNAL REPO UPDATE (CLONE/PULL) ---
sync_external_repos() {
    local has_external_repos
    has_external_repos=$(jq -r 'if ((.external_repos // []) | type == "array" and length > 0) then "true" else "false" end' "$CONFIG_FILE")

    if [[ "$has_external_repos" != "true" ]]; then
        echo "ℹ️  No external repositories configured."
        return
    fi

    echo "🔄 Syncing configured external repositories..."
    jq -r '.external_repos[]? // empty' "$CONFIG_FILE" | while IFS= read -r repo_url; do
        local repo_slug repo_name repo_path
        [[ -n "$repo_url" ]] || continue

        repo_slug="$(normalize_external_slug "$repo_url")"
        if [[ -z "$repo_slug" ]]; then
            echo "⚠️  Skipping invalid external repo URL: $repo_url"
            continue
        fi

        repo_name="$(basename "$repo_slug")"
        repo_path="$EXTERNAL_REPOS_DIR/$repo_slug"
        mkdir -p "$(dirname "$repo_path")"

        if [[ -d "$repo_path/.git" ]]; then
            echo "⬇️  Pulling latest: $repo_slug"
            if [[ "$DRY_RUN" = false ]]; then
                git -C "$repo_path" pull --ff-only || echo "⚠️  Pull failed for $repo_name"
            fi
        elif [[ -e "$repo_path" ]]; then
            echo "⚠️  Skipping clone for $repo_name (path exists but is not a git repo)"
        else
            echo "📥 Cloning: $repo_url"
            if [[ "$DRY_RUN" = false ]]; then
                git clone "$repo_url" "$repo_path" || echo "⚠️  Clone failed for $repo_url"
            fi
        fi
    done
}

# --- PRUNE REMOVED EXTERNAL REPOS ---
prune_external_repos() {
    local configured_slugs
    configured_slugs=$(jq -r '.external_repos[]? // empty' "$CONFIG_FILE" | while IFS= read -r repo_url; do
        normalize_external_slug "$repo_url"
    done)

    # Support org/repo layout, while also cleaning legacy one-level clones.
    find "$EXTERNAL_REPOS_DIR" -mindepth 1 -maxdepth 2 -type d | while IFS= read -r repo_path; do
        local rel_path
        [[ -d "$repo_path/.git" ]] || continue
        rel_path="${repo_path#$EXTERNAL_REPOS_DIR/}"

        if ! echo "$configured_slugs" | grep -qx "$rel_path"; then
            echo "🗑️  Removing unconfigured external repo: $rel_path"
            [ "$DRY_RUN" = false ] && rm -rf "$repo_path"
        fi
    done
}

# --- JQ LOGIC ENGINE ---
check_config() {
    local config_key=$1
    local repo=$2
    local item_full_name=$3
    local item_base_name="${item_full_name%.agent.md}"

    jq -r --arg repo "$repo" --arg item_full "$item_full_name" --arg item_base "$item_base_name" --arg key "$config_key" '
        def match_rule(r; val_full; val_base; pattern):
            (if pattern == "*" then ".*" else pattern | gsub("\\."; "\\.") end) as $p |
            if r.type == "Literal" then 
                (pattern == "*" or val_full == pattern or val_base == pattern)
            else 
                (val_full | test($p)) or (val_base | test($p))
            end;

        def is_in_list(list; r_val; i_full; i_base; item_key):
            any(list[]; . as $rule | 
                match_rule($rule; r_val; r_val; $rule.repo) and 
                match_rule($rule; i_full; i_base; $rule[item_key])
            );

        .[$key] as $cfg |
        ($cfg.apply_order // $cfg.priority_order // ["whitelist", "blacklist"]) as $order |
        
        reduce $order[] as $step (false;
            if $step == "whitelist" then 
                if is_in_list($cfg.whitelist // []; $repo; $item_full; $item_base; (if $key == "agaent_config" then "agent" else "skill" end)) then true else . end
            elif $step == "blacklist" then
                if is_in_list($cfg.blacklist // []; $repo; $item_full; $item_base; (if $key == "agaent_config" then "agent" else "skill" end)) then false else . end
            else . end
        )
    ' "$CONFIG_FILE"
}

echo "🚀 Syncing AI Registry..."
sync_external_repos
prune_external_repos

# --- 1. SYNC AGENTS ---
for source_root in "$EXTERNAL_REPOS_DIR" "$CUSTOM_REPOS_DIR"; do
    [[ -d "$source_root" ]] || continue
    find "$source_root" -type f -name "*.agent.md" | while read -r src; do
        relative_path=${src#$source_root/}
        repo_name=$(repo_id_for_item "$source_root" "$relative_path")
        agent_filename=$(basename "$src")
        dest="$AGENTS_TARGET/$(basename "$repo_name"):${agent_filename}"

        if [[ $(check_config "agaent_config" "$repo_name" "$agent_filename") == "true" ]]; then
            echo "✅ Linking Agent: $(basename "$dest") (Repo: $repo_name)"
            [ "$DRY_RUN" = false ] && ln -sf "$src" "$dest"
        else
            [ -L "$dest" ] && echo "🗑️  Removing Agent: $(basename "$dest")" && [ "$DRY_RUN" = false ] && rm -f "$dest"
        fi
    done
done

# --- 2. SYNC SKILLS ---
for source_root in "$EXTERNAL_REPOS_DIR" "$CUSTOM_REPOS_DIR"; do
    [[ -d "$source_root" ]] || continue
    find "$source_root" -type f -iname "SKILL.md" | while read -r skill_file; do
        src_dir=$(dirname "$skill_file")
        relative_path=${src_dir#$source_root/}
        repo_name=$(repo_id_for_item "$source_root" "$relative_path")
        skill_name=$(basename "$src_dir")
        dest="$SKILLS_TARGET/$(basename "$repo_name"):${skill_name}"

        if [[ $(check_config "skill_config" "$repo_name" "$skill_name") == "true" ]]; then
            echo "✅ Linking Skill: $(basename "$dest") (Repo: $repo_name)"
            [ "$DRY_RUN" = false ] && ln -sfn "$src_dir" "$dest"
        else
            [ -L "$dest" ] && echo "🗑️  Removing Skill: $(basename "$dest")" && [ "$DRY_RUN" = false ] && rm -f "$dest"
        fi
    done
done

# --- 3. CLEANUP (Ignoring nested skills in agents) ---
echo "🗑️  Phase 3: Garbage Collection..."

# Find broken symlinks in SKILLS_TARGET
find "$SKILLS_TARGET" -type l ! -exec test -e {} \; -delete 2>/dev/null

# Find broken symlinks in AGENTS_TARGET, but EXCLUDE the 'skills' subdirectory
find "$AGENTS_TARGET" -path "$AGENTS_TARGET/skills" -prune -o -type l ! -exec test -e {} \; -print | while read -r broken_link; do
    echo "💀 Removing broken agent link: $(basename "$broken_link")"
    [ "$DRY_RUN" = false ] && rm -f "$broken_link"
done

echo "✅ Sync Complete!"
