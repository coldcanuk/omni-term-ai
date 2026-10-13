# FIM Bash Completion
# Binds Ctrl-F to the configured FIM provider.
# Tab stays with bash programmable completion.

_omni_fim_apply_choice() {
    # $1 json file, $2 prefix, $3 suffix, $4 pick (1-based, empty if one choice).
    # Writes $1.line and $1.point. Never evals model text.
    python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, pathlib, sys
src, prefix, suffix, pick = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = json.loads(pathlib.Path(src).read_text())
choices = data.get("choices") or []
if not choices:
    sys.exit(2)
if len(choices) == 1 and not pick:
    idx = 0
elif pick.isdigit() and 1 <= int(pick) <= len(choices):
    idx = int(pick) - 1
else:
    sys.exit(3)
choice = choices[idx]
pathlib.Path(src + ".line").write_text(prefix + choice + suffix)
pathlib.Path(src + ".point").write_text(str(len(prefix) + len(choice)))
PY
}

_omni_deepseek_completion() {
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "omni: python3 is required for shell completion" >&2
        return 0
    fi

    local line="${READLINE_LINE-}"
    local point="${READLINE_POINT-0}"
    local prefix="${line:0:point}"
    local suffix="${line:point}"
    local tmp json pick n

    tmp=$(mktemp)
    json=$(python3 -c '
import sys, json, urllib.request, os

prefix = sys.argv[1]
suffix = sys.argv[2]
api_key = os.environ.get("DEEPSEEK_API_KEY")
azure_key = os.environ.get("AZURE_OPENAI_API_KEY")
azure_endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
azure_deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT")
openai_key = os.environ.get("OPENAI_API_KEY")
provider = os.environ.get("OMNI_FIM_PROVIDER", "deepseek")

if not prefix.strip() and not os.environ.get("OMNI_FIM_FAKE_CHOICES"):
    sys.exit(0)

endpoint = "https://api.deepseek.com/beta/completions"
model = "deepseek-v4-pro"
headers = {"Content-Type": "application/json"}

if provider == "azure":
    if not (azure_key and azure_endpoint and azure_deployment):
        sys.exit(0)
    endpoint = azure_endpoint.rstrip("/") + f"/openai/deployments/{azure_deployment}/completions?api-version=2024-02-15-preview"
    headers["api-key"] = azure_key
elif provider == "openai":
    if not openai_key:
        sys.exit(0)
    endpoint = "https://api.openai.com/v1/completions"
    model = "gpt-3.5-turbo-instruct"
    headers["Authorization"] = "Bearer " + openai_key
elif provider == "deepseek":
    if not api_key:
        sys.exit(0)
    headers["Authorization"] = "Bearer " + api_key
else:
    sys.exit(0)

if os.environ.get("OMNI_FIM_DRY") == "1":
    print(endpoint)
    sys.exit(0)

fake = os.environ.get("OMNI_FIM_FAKE_CHOICES")
if fake:
    choices = json.loads(fake)
    json.dump({"choices": choices}, sys.stdout)
    sys.exit(0)

req_data = {
    "model": model,
    "prompt": prefix,
    "max_tokens": 128,
    "n": 3,
    "temperature": 0.2,
}
if suffix:
    req_data["suffix"] = suffix

req = urllib.request.Request(
    endpoint,
    data=json.dumps(req_data).encode("utf-8"),
    headers=headers,
)
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception:
    sys.exit(0)

choices = []
for c in data.get("choices", []):
    txt = c.get("text", "")
    if txt and txt not in choices:
        choices.append(txt)
json.dump({"choices": choices}, sys.stdout)
' "$prefix" "$suffix") || { rm -f "$tmp"; return 0; }

    if [ -z "$json" ]; then
        rm -f "$tmp"
        return 0
    fi
    # Dry-run prints a URL, not a choice list. Leave the line alone.
    case $json in
        http*) rm -f "$tmp"; return 0 ;;
    esac

    printf '%s' "$json" > "$tmp"
    n=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("choices") or []))' "$tmp")
    if [ "$n" -eq 0 ]; then
        rm -f "$tmp"
        return 0
    fi

    pick=${OMNI_FIM_PICK:-}
    if [ "$n" -gt 1 ] && [ -z "$pick" ]; then
        python3 -c '
import json, sys
choices = json.load(open(sys.argv[1])).get("choices") or []
for i, c in enumerate(choices, 1):
    preview = c.replace("\n", "\\n")
    print(f"{i}) {preview}", file=sys.stderr)
print("omni pick [1-%d]: " % len(choices), file=sys.stderr, end="")
' "$tmp" >&2
        if [ -r /dev/tty ]; then
            IFS= read -r pick </dev/tty || pick=
        else
            pick=
        fi
    fi

    if ! _omni_fim_apply_choice "$tmp" "$prefix" "$suffix" "$pick"; then
        rm -f "$tmp" "$tmp.line" "$tmp.point"
        return 0
    fi
    # Keep trailing newlines that command substitution would strip.
    READLINE_LINE=$(python3 -c 'import pathlib,sys; sys.stdout.write(pathlib.Path(sys.argv[1]).read_text() + "\x01")' "$tmp.line")
    READLINE_LINE=${READLINE_LINE%$'\x01'}
    READLINE_POINT=$(cat "$tmp.point")
    rm -f "$tmp" "$tmp.line" "$tmp.point"
}

# Bind only in an interactive shell. A missing readline is not a failed login.
if [[ $- == *i* ]]; then
    bind -x '"\C-f": _omni_deepseek_completion'
fi
