# DeepSeek Bash Completion
# Binds <C-f> to DeepSeek AI completion.
# (Leaving <Tab> strictly for standard bash programmable completion)

_omni_deepseek_completion() {
    local line="${READLINE_LINE}"
    local point="${READLINE_POINT}"
    local prefix="${line:0:point}"
    local suffix="${line:point}"
    
    local cmd=$(python3 -c '
import sys, json, urllib.request, os, shutil

prefix = sys.argv[1]
suffix = sys.argv[2]
api_key = os.environ.get("DEEPSEEK_API_KEY")
azure_key = os.environ.get("AZURE_OPENAI_API_KEY")
azure_endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
azure_deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT")
openai_key = os.environ.get("OPENAI_API_KEY")

if not prefix.strip():
    sys.exit(0)

endpoint = "https://api.deepseek.com/beta/completions"
model = "deepseek-v4-pro"
headers = {"Content-Type": "application/json"}

if azure_key and azure_endpoint and azure_deployment:
    endpoint = azure_endpoint.rstrip("/") + f"/openai/deployments/{azure_deployment}/completions?api-version=2024-02-15-preview"
    headers["api-key"] = azure_key
elif openai_key:
    endpoint = "https://api.openai.com/v1/completions"
    model = "gpt-3.5-turbo-instruct"
    headers["Authorization"] = f"Bearer {openai_key}"
elif api_key:
    headers["Authorization"] = f"Bearer {api_key}"
else:
    sys.exit(0)

req_data = {
    "model": model,
    "prompt": prefix,
    "max_tokens": 128,
    "n": 3,
    "temperature": 0.2
}
if suffix: req_data["suffix"] = suffix

req = urllib.request.Request(
    endpoint,
    data=json.dumps(req_data).encode("utf-8"),
    headers=headers
)

try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    sys.exit(0)

choices = []
for c in data.get("choices", []):
    txt = c.get("text", "")
    if txt and txt not in choices:
        choices.append(txt)

if not choices:
    sys.exit(0)

if len(choices) == 1:
    # Single choice, insert it inline
    choice = choices[0]
    new_line = prefix + choice + suffix
    new_point = len(prefix) + len(choice)
    new_line_esc = new_line.replace("\x27", "\x27\\\x27\x27")
    print(f"READLINE_LINE=\x27{new_line_esc}\x27")
    print(f"READLINE_POINT={new_point}")
else:
    # Multiple choices: present above cursor in max 3 columns
    cols_count = min(len(choices), 3)
    term_width = shutil.get_terminal_size().columns or 80
    col_width = term_width // cols_count
    
    print("echo \"\" >&2")
    
    for i in range(0, len(choices), cols_count):
        row = choices[i:i+cols_count]
        formatted = ""
        for item in row:
            display = item.replace("\n", "\\n").replace("\r", "")
            if len(display) > col_width - 3:
                display = display[:col_width - 4] + "..."
            formatted += display.ljust(col_width)
        esc = formatted.replace("\x27", "\x27\\\x27\x27")
        print(f"echo \x27{esc}\x27 >&2")
' "$prefix" "$suffix")

    if [ -n "$cmd" ]; then
        eval "$cmd"
    fi
}

# Bind Ctrl-F to DeepSeek AI Completion
bind -x '"\C-f": _omni_deepseek_completion'
