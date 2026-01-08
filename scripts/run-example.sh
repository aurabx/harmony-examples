#!/usr/bin/env bash
set -euo pipefail

# Build list of runnable examples from pipelines.json:
# - Use the catalog to determine pipeline directories and names
# - Only include examples that have a demo.sh file

PIPELINES_JSON="pipelines.json"
if [ ! -f "$PIPELINES_JSON" ]; then
  echo "pipelines.json not found in project root"
  exit 1
fi

# Extract keys (IDs) from pipelines.json in a stable order
mapfile -t pipeline_ids < <(jq -r 'keys[]' "$PIPELINES_JSON" | sort)

scripts=()
names=()

for id in "${pipeline_ids[@]}"; do
  dir=$(jq -r --arg id "$id" '.[$id].directory // empty' "$PIPELINES_JSON")
  name=$(jq -r --arg id "$id" '.[$id].name // empty' "$PIPELINES_JSON")
  hidden=$(jq -r --arg id "$id" '.[$id].hidden // false' "$PIPELINES_JSON")

  # Skip entries without a directory or that are hidden
  if [ -z "$dir" ] || [ "$dir" = "null" ] || [ "$hidden" = "true" ]; then
    continue
  fi

  # Derive example directory
  example_dir="pipelines/$dir"
  
  if [ ! -d "$example_dir" ]; then
    # Skip catalog entries that don't have a matching directory in this repo
    continue
  fi

  # Only include examples with demo.sh
  if [ -f "$example_dir/demo.sh" ]; then
    scripts+=("$example_dir/demo.sh")
    names+=("$name")
  fi
done

if [ ${#scripts[@]} -eq 0 ]; then
    echo "No runnable examples found from pipelines.json (check pipelines/* directories)"
    exit 1
fi

# Check if an argument was provided
if [ $# -eq 1 ]; then
    target="$1"
    # Try to find matching example by directory name
    for i in "${!scripts[@]}"; do
        dir=$(dirname "${scripts[$i]}")
        dir_name=$(basename "$dir")
        if [ "$dir_name" == "$target" ]; then
            selected="${scripts[$i]}"
            selected_name="${names[$i]}"
            echo "Selected example: $selected_name"
            break
        fi
    done

    if [ -z "${selected:-}" ]; then
        # Try to interpret as a number
        if [[ "$target" =~ ^[0-9]+$ ]] && [ "$target" -ge 1 ] && [ "$target" -le ${#scripts[@]} ]; then
            selected="${scripts[$((target-1))]}"
            selected_name="${names[$((target-1))]}"
        else
            echo "Error: Example '$target' not found."
            echo "Available examples:"
            for i in "${!scripts[@]}"; do
                dir=$(dirname "${scripts[$i]}")
                dir_name=$(basename "$dir")
                echo "  $dir_name - ${names[$i]}"
            done
            exit 1
        fi
    fi
else
    # Interactive mode
    echo "Available Examples:"
    echo "==================="
    for i in "${!scripts[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${names[$i]}"
    done
    echo ""
    echo " q) Quit"
    echo ""

    read -rp "Select example to run: " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Exiting"
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#scripts[@]} ]; then
        echo "Invalid selection"
        exit 1
    fi

    selected="${scripts[$((choice-1))]}"
    selected_name="${names[$((choice-1))]}"
fi

dir=$(dirname "$selected")

echo ""
echo "Running: $selected_name"
echo "=========================================="
echo ""

# All runnable examples have demo.sh, so just run it
cd "$dir" && bash demo.sh
