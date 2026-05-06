#!/usr/bin/env bash

# --- CONFIGURATION ---
export CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" >/dev/null 2>&1 && pwd )"
BASE_DIR="$CURRENT_DIR"
REPOS_ROOT="$BASE_DIR/repos"
EXTERNAL_REPOS_DIR="$REPOS_ROOT/external-repos"
CUSTOM_REPOS_DIR="$REPOS_ROOT/custom-repos"
CONFIG_FILE="$REPOS_ROOT/config.json"
AGENTS_TARGET="$BASE_DIR/artifacts/synced-items/agents"
SKILLS_TARGET="$BASE_DIR/artifacts/synced-items/skills"
NAME_DELIMITER="."

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

# --- PORTABLE SED IN-PLACE ---
sed_inplace() {
    if sed --version >/dev/null 2>&1; then
        # GNU sed (Linux, Git Bash on Windows)
        sed -i "$@"
    else
        # BSD sed (macOS)
        sed -i '' "$@"
    fi
}

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

# --- PATCH SKILL NAMES IN EXTERNAL REPO ---
patch_skill_names() {
    local repo_path="$1"
    local repo_slug="$2"

    local should_patch
    should_patch=$(jq -r '.patch_skill_names // true' "$CONFIG_FILE")
    [[ "$should_patch" == "true" ]] || return 0

    local repo_base
    repo_base="$(basename "$repo_slug")"

    # Collect all skill names and their file paths into a temp file (tab-separated)
    local tmpfile
    tmpfile=$(mktemp)
    find "$repo_path" -type f -iname "SKILL.md" | while IFS= read -r skill_file; do
        local skill_dir skill_name
        skill_dir="$(dirname "$skill_file")"
        skill_name="$(basename "$skill_dir")"
        printf '%s\t%s\n' "$skill_name" "$skill_file"
    done > "$tmpfile"

    [[ -s "$tmpfile" ]] || { rm -f "$tmpfile"; return 0; }

    # Extract just skill names for batch filtering
    local all_skills
    all_skills=$(awk -F'\t' '{print $1}' "$tmpfile" | sort -u)

    # Single jq call to get matching skills
    local matched
    matched=$(echo "$all_skills" | jq -R -r --arg repo "$repo_slug" --arg key "skill_config" --slurpfile cfg "$CONFIG_FILE" '
        . as $item_name |
        select($item_name != "") |
        $cfg[0][$key] as $cfgblock |
        ($cfgblock.apply_order // $cfgblock.priority_order // ["whitelist", "blacklist"]) as $order |

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

        (reduce $order[] as $step (false;
            if $step == "whitelist" then
                if is_in_list($cfgblock.whitelist // []; $repo; $item_name; $item_name; "skill") then true else . end
            elif $step == "blacklist" then
                if is_in_list($cfgblock.blacklist // []; $repo; $item_name; $item_name; "skill") then false else . end
            else . end
        )) as $result |
        if $result then $item_name else empty end
    ')

    # Patch only matched skills
    echo "$matched" | while IFS= read -r skill_name; do
        [[ -n "$skill_name" ]] || continue
        local skill_file
        skill_file=$(awk -F'\t' -v skill="$skill_name" '$1 == skill {print $2; exit}' "$tmpfile")
        [[ -n "$skill_file" ]] || continue
        local new_name="${repo_base}${NAME_DELIMITER}${skill_name}"
        sed_inplace "s/^name: .*/name: ${new_name}/" "$skill_file"
        echo "  📝 Patched skill name → ${new_name}"
    done

    rm -f "$tmpfile"
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
                git -C "$repo_path" reset --hard HEAD 2>/dev/null
                if ! git -C "$repo_path" pull --ff-only 2>/dev/null; then
                    echo "⚠️  Pull failed for $repo_name, re-cloning..."
                    rm -rf "$repo_path"
                    if ! git clone "$repo_url" "$repo_path"; then
                        echo "⚠️  Clone failed for $repo_url"
                        continue
                    fi
                fi
                patch_skill_names "$repo_path" "$repo_slug"
            fi
        elif [[ -e "$repo_path" ]]; then
            echo "⚠️  Skipping clone for $repo_name (path exists but is not a git repo)"
        else
            echo "📥 Cloning: $repo_url"
            if [[ "$DRY_RUN" = false ]]; then
                if git clone "$repo_url" "$repo_path"; then
                    patch_skill_names "$repo_path" "$repo_slug"
                else
                    echo "⚠️  Clone failed for $repo_url"
                fi
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

# Returns newline-separated list of skill names that pass config for a given repo
# Single jq call for all candidates — avoids per-skill subprocess overhead
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
        dest="$AGENTS_TARGET/$(basename "$repo_name")${NAME_DELIMITER}${agent_filename}"

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

    # Collect all skills into a temp file: repo_name<TAB>skill_name<TAB>src_dir
    _skill_tmp=$(mktemp)
    find "$source_root" -type f -iname "SKILL.md" | while IFS= read -r skill_file; do
        src_dir=$(dirname "$skill_file")
        relative_path=${src_dir#$source_root/}
        repo_name=$(repo_id_for_item "$source_root" "$relative_path")
        skill_name=$(basename "$src_dir")
        printf '%s\t%s\t%s\n' "$repo_name" "$skill_name" "$src_dir"
    done > "$_skill_tmp"

    # Get unique repos
    _repos=$(awk -F'\t' '{print $1}' "$_skill_tmp" | sort -u)

    # Process each repo with a single batch jq call
    echo "$_repos" | while IFS= read -r repo_name; do
        [[ -n "$repo_name" ]] || continue

        # Extract skill names for this repo (unique, exact field match)
        _repo_skills=$(awk -F'\t' -v repo="$repo_name" '$1 == repo {print $2}' "$_skill_tmp" | sort -u)

        # Get matching skills in one jq call
        matched_skills=$(echo "$_repo_skills" | jq -R -r --arg repo "$repo_name" --arg key "skill_config" --slurpfile cfg "$CONFIG_FILE" '
            . as $item_name |
            select($item_name != "") |
            $cfg[0][$key] as $cfgblock |
            ($cfgblock.apply_order // $cfgblock.priority_order // ["whitelist", "blacklist"]) as $order |

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

            (reduce $order[] as $step (false;
                if $step == "whitelist" then
                    if is_in_list($cfgblock.whitelist // []; $repo; $item_name; $item_name; "skill") then true else . end
                elif $step == "blacklist" then
                    if is_in_list($cfgblock.blacklist // []; $repo; $item_name; $item_name; "skill") then false else . end
                else . end
            )) as $result |
            if $result then $item_name else empty end
        ')

        # Link matched skills
        echo "$matched_skills" | while IFS= read -r skill_name; do
            [[ -n "$skill_name" ]] || continue
            src_dir=$(awk -F'\t' -v repo="$repo_name" -v skill="$skill_name" '$1 == repo && $2 == skill {print $3; exit}' "$_skill_tmp")
            dest="$SKILLS_TARGET/$(basename "$repo_name")${NAME_DELIMITER}${skill_name}"
            echo "✅ Linking Skill: $(basename "$dest") (Repo: $repo_name)"
            [ "$DRY_RUN" = false ] && ln -sfn "$src_dir" "$dest"
        done

        # Remove symlinks for non-matched skills
        echo "$_repo_skills" | while IFS= read -r skill_name; do
            [[ -n "$skill_name" ]] || continue
            if ! echo "$matched_skills" | grep -qxF "$skill_name"; then
                dest="$SKILLS_TARGET/$(basename "$repo_name")${NAME_DELIMITER}${skill_name}"
                [ -L "$dest" ] && echo "🗑️  Removing Skill: $(basename "$dest")" && [ "$DRY_RUN" = false ] && rm -f "$dest"
            fi
        done
    done

    rm -f "$_skill_tmp"
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

# --- 4. SYNC TO ~/.copilot/ (agents & skills) ---
SYNC_TO_COPILOT=$(jq -r '.sync_to_copilot_home // false' "$CONFIG_FILE")
if [[ "$SYNC_TO_COPILOT" == "true" ]]; then
    COPILOT_HOME="$HOME/.copilot"
    COPILOT_AGENTS="$COPILOT_HOME/agents"
    COPILOT_SKILLS="$COPILOT_HOME/skills"
    mkdir -p "$COPILOT_AGENTS" "$COPILOT_SKILLS"

    echo "🏠 Phase 4: Syncing to ~/.copilot/ ..."

    # Mirror agent symlinks
    # First, remove managed symlinks in ~/.copilot/agents that no longer exist in artifacts
    find "$COPILOT_AGENTS" -maxdepth 1 -type l | while IFS= read -r link; do
        link_name="$(basename "$link")"
        if [[ ! -L "$AGENTS_TARGET/$link_name" ]]; then
            echo "🗑️  Removing agent from ~/.copilot: $link_name"
            [ "$DRY_RUN" = false ] && rm -f "$link"
        fi
    done

    # Create/update agent symlinks — point to same targets as artifacts
    find "$AGENTS_TARGET" -maxdepth 1 -type l | while IFS= read -r link; do
        link_name="$(basename "$link")"
        link_target="$(readlink "$link")"
        dest="$COPILOT_AGENTS/$link_name"
        echo "🏠 Linking Agent → ~/.copilot/agents/$link_name"
        [ "$DRY_RUN" = false ] && ln -sf "$link_target" "$dest"
    done

    # Mirror skill symlinks
    # First, remove managed symlinks in ~/.copilot/skills that no longer exist in artifacts
    find "$COPILOT_SKILLS" -maxdepth 1 -type l | while IFS= read -r link; do
        link_name="$(basename "$link")"
        if [[ ! -L "$SKILLS_TARGET/$link_name" ]]; then
            echo "🗑️  Removing skill from ~/.copilot: $link_name"
            [ "$DRY_RUN" = false ] && rm -f "$link"
        fi
    done

    # Create/update skill symlinks — point to same targets as artifacts
    find "$SKILLS_TARGET" -maxdepth 1 -type l | while IFS= read -r link; do
        link_name="$(basename "$link")"
        link_target="$(readlink "$link")"
        dest="$COPILOT_SKILLS/$link_name"
        echo "🏠 Linking Skill → ~/.copilot/skills/$link_name"
        [ "$DRY_RUN" = false ] && ln -sfn "$link_target" "$dest"
    done

    # Clean broken symlinks in ~/.copilot
    find "$COPILOT_AGENTS" -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null
    find "$COPILOT_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null
fi

echo "✅ Sync Complete!"
