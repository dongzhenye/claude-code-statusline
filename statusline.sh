#!/bin/sh
# Claude Code status line (v5)
# https://github.com/dongzhenye/claude-code-statusline
#
# Four zones, ordered by scope and urgency:
#   Location      — dir(branch)
#   Model         — opus-4.6-1m
#   Session Usage — context bar + cost
#   User Usage    — 7d pace bar + 5h alert (conditional)
#
# Git results are cached in /tmp/claude-statusline-git-cache for 5 seconds.

# ---------------------------------------------------------------------------
# Parse all needed fields in a single jq call
# ---------------------------------------------------------------------------
input=$(cat)

parsed=$(printf '%s' "$input" | jq -r '
  (.workspace.project_dir // .workspace.current_dir // ""),
  (.model.display_name // ""),
  ((.context_window.used_percentage // "null") | tostring),
  ((.cost.total_cost_usd // 0) | tostring),
  ((.rate_limits.seven_day.used_percentage // "null") | tostring),
  ((.rate_limits.seven_day.resets_at // "null") | tostring),
  ((.rate_limits.five_hour.used_percentage // "null") | tostring),
  ((.rate_limits.five_hour.resets_at // "null") | tostring)
')

cwd=$(printf '%s\n' "$parsed" | sed -n '1p')
model_display=$(printf '%s\n' "$parsed" | sed -n '2p')
used_pct_raw=$(printf '%s\n' "$parsed" | sed -n '3p')
cost_usd=$(printf '%s\n' "$parsed" | sed -n '4p')
seven_day_pct=$(printf '%s\n' "$parsed" | sed -n '5p')
seven_day_resets=$(printf '%s\n' "$parsed" | sed -n '6p')
five_hour_pct=$(printf '%s\n' "$parsed" | sed -n '7p')
five_hour_resets=$(printf '%s\n' "$parsed" | sed -n '8p')

# ---------------------------------------------------------------------------
# ANSI color helpers
# ---------------------------------------------------------------------------
DIM=$(printf '\033[2m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
ORANGE=$(printf '\033[38;5;202m')
RED=$(printf '\033[38;5;196m')
CYAN=$(printf '\033[36m')
RESET=$(printf '\033[0m')

SEP="${DIM} │ ${RESET}"

# ---------------------------------------------------------------------------
# Zone 1: Location — dir(branch)
# ---------------------------------------------------------------------------

CACHE_FILE="/tmp/claude-statusline-git-cache"
CACHE_TTL=5  # seconds

git_dir=$(git -C "$cwd" --no-optional-locks rev-parse --git-dir 2>/dev/null)

if [ -n "$git_dir" ]; then
  git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  cache_key=$(printf '%s' "$git_root" | tr '/' '_')
  cache_path="${CACHE_FILE}_${cache_key}"
  cache_ts_path="${cache_path}.ts"

  cache_valid=0
  if [ -f "$cache_path" ] && [ -f "$cache_ts_path" ]; then
    fresh=$(find "$cache_ts_path" -newer /dev/null -mtime -"${CACHE_TTL}"s 2>/dev/null)
    if [ -z "$fresh" ]; then
      cached_ts=$(cat "$cache_ts_path" 2>/dev/null)
      now=$(date +%s)
      if [ -n "$cached_ts" ] && [ $((now - cached_ts)) -lt $CACHE_TTL ]; then
        cache_valid=1
      fi
    else
      cache_valid=1
    fi
  fi

  if [ "$cache_valid" -eq 1 ]; then
    cached=$(cat "$cache_path")
    branch=$(printf '%s' "$cached" | cut -d'|' -f1)
    dirty=$(printf '%s' "$cached" | cut -d'|' -f2)
  else
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null || \
       ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; then
      dirty=1
    else
      dirty=0
    fi
    printf '%s|%s' "$branch" "$dirty" > "$cache_path"
    date +%s > "$cache_ts_path"
  fi
fi

dir_name=""
case "$cwd" in
  "$HOME"|"$HOME"/|"") ;;
  *) dir_name=$(basename "$cwd") ;;
esac

location_section=""
if [ -n "$dir_name" ] && [ -n "$branch" ]; then
  if [ "$dirty" = "1" ]; then
    branch_color="$YELLOW"
  else
    branch_color="$GREEN"
  fi
  location_section="${dir_name}${DIM}(${RESET}${branch_color}${branch}${RESET}${DIM})${RESET}"
elif [ -n "$dir_name" ]; then
  location_section="$dir_name"
elif [ -n "$branch" ]; then
  if [ "$dirty" = "1" ]; then
    branch_color="$YELLOW"
  else
    branch_color="$GREEN"
  fi
  location_section="${branch_color}${branch}${RESET}"
fi

# ---------------------------------------------------------------------------
# Zone 2: Model name
# ---------------------------------------------------------------------------
model_slug=$(printf '%s' "$model_display" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/^claude //' \
  | sed 's/ *context//g' \
  | sed 's/[()]//g' \
  | tr ' ' '-')

model_section="${CYAN}${model_slug}${RESET}"

# ---------------------------------------------------------------------------
# Zone 3: Session Usage — context bar + cost (no separator between them)
# ---------------------------------------------------------------------------
session_section=""

if [ "$used_pct_raw" != "null" ] && [ -n "$used_pct_raw" ]; then
  used_int=$(printf '%.0f' "$used_pct_raw")

  filled=$((used_int / 10))
  [ "$filled" -gt 10 ] && filled=10
  empty=$((10 - filled))

  if [ "$used_int" -ge 90 ]; then
    bar_color="$RED"
  elif [ "$used_int" -ge 70 ]; then
    bar_color="$ORANGE"
  elif [ "$used_int" -ge 50 ]; then
    bar_color="$YELLOW"
  else
    bar_color="$GREEN"
  fi

  bar=""
  i=0
  while [ $i -lt "$filled" ]; do
    bar="${bar}${bar_color}█${RESET}"
    i=$((i + 1))
  done
  i=0
  while [ $i -lt "$empty" ]; do
    bar="${bar}${DIM}░${RESET}"
    i=$((i + 1))
  done

  session_section="${bar} ${bar_color}${used_int}%${RESET}"
fi

cost=$(printf '%.2f' "$cost_usd")
cost_part="${DIM}\$${cost}${RESET}"

if [ -n "$session_section" ]; then
  session_section="${session_section} ${cost_part}"
else
  session_section="$cost_part"
fi

# ---------------------------------------------------------------------------
# Zone 4: User Usage — 7d pace bar + 5h alert
# ---------------------------------------------------------------------------
user_section=""

if [ "$seven_day_pct" != "null" ] && [ -n "$seven_day_pct" ]; then
  now=$(date +%s)

  seven_day_actual=$(printf '%.0f' "$seven_day_pct")
  if [ "$seven_day_resets" != "null" ] && [ -n "$seven_day_resets" ]; then
    resets_int=$(printf '%.0f' "$seven_day_resets")
    remaining=$((resets_int - now))
    [ "$remaining" -lt 0 ] && remaining=0
    window_total=$((7 * 24 * 3600))
    elapsed=$((window_total - remaining))
    [ "$elapsed" -lt 0 ] && elapsed=0
    [ "$elapsed" -gt "$window_total" ] && elapsed=$window_total
    elapsed_pct=$((elapsed * 100 / window_total))
  else
    elapsed_pct=0
  fi

  actual_filled=$((seven_day_actual / 10))
  [ "$actual_filled" -gt 10 ] && actual_filled=10

  pace_delta=$((seven_day_actual - elapsed_pct))

  if [ "$pace_delta" -ge 5 ]; then
    pace_color="$GREEN"
  elif [ "$pace_delta" -ge -5 ]; then
    pace_color="$YELLOW"
  else
    pace_color="$ORANGE"
  fi

  user_bar=""
  i=0
  while [ $i -lt "$actual_filled" ]; do
    user_bar="${user_bar}${pace_color}█${RESET}"
    i=$((i + 1))
  done
  remaining_slots=$((10 - actual_filled))
  i=0
  while [ $i -lt "$remaining_slots" ]; do
    user_bar="${user_bar}${DIM}░${RESET}"
    i=$((i + 1))
  done

  countdown_7d=""
  if [ "$seven_day_resets" != "null" ] && [ -n "$seven_day_resets" ]; then
    remaining_min_7d=$((remaining / 60))
    if [ "$remaining_min_7d" -ge 1440 ]; then
      countdown_7d="$((remaining_min_7d / 1440))d"
    elif [ "$remaining_min_7d" -ge 60 ]; then
      countdown_7d="$((remaining_min_7d / 60))h"
    else
      countdown_7d="${remaining_min_7d}m"
    fi
  fi

  user_section="${user_bar} ${pace_color}${seven_day_actual}%${RESET}"
  if [ -n "$countdown_7d" ]; then
    user_section="${user_section} ${DIM}${countdown_7d}${RESET}"
  fi
fi

# 5h alert (conditional, only when >80%)
if [ "$five_hour_pct" != "null" ] && [ -n "$five_hour_pct" ]; then
  five_hour_int=$(printf '%.0f' "$five_hour_pct")
  if [ "$five_hour_int" -gt 80 ]; then
    countdown_str=""
    if [ "$five_hour_resets" != "null" ] && [ -n "$five_hour_resets" ]; then
      resets_5h=$(printf '%.0f' "$five_hour_resets")
      [ -z "$now" ] && now=$(date +%s)
      remaining_5h=$((resets_5h - now))
      [ "$remaining_5h" -lt 0 ] && remaining_5h=0

      remaining_min=$((remaining_5h / 60))
      if [ "$remaining_min" -ge 1440 ]; then
        countdown_str="$((remaining_min / 1440))d"
      elif [ "$remaining_min" -ge 60 ]; then
        countdown_str="$((remaining_min / 60))h"
      else
        countdown_str="${remaining_min}m"
      fi
    fi

    alert="${RED}${five_hour_int}%"
    if [ -n "$countdown_str" ]; then
      alert="${alert} ${countdown_str}"
    fi
    alert="${alert}${RESET}"

    if [ -n "$user_section" ]; then
      user_section="${user_section} ${alert}"
    else
      user_section="$alert"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Assemble — join non-empty sections with separator
# ---------------------------------------------------------------------------
output=""
for section in "$location_section" "$model_section" "$session_section" "$user_section"; do
  [ -z "$section" ] && continue
  if [ -n "$output" ]; then
    output="${output}${SEP}${section}"
  else
    output="$section"
  fi
done
printf '%s' "$output"
