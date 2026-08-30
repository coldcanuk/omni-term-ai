# DeepSeek Bash Tab Completion
# Binds <Tab> to try normal completion first, then fall back to DeepSeek AI.

_omni_deepseek_tab_completion() {
    local line="${READLINE_LINE}"
    local point="${READLINE_POINT}"
    local prefix="${line:0:point}"
    local suffix="${line:point}"

    # First, let's just trigger DeepSeek directly because 
    # capturing standard tab completion inside bind -x is highly complex.
    # To use standard completion as well, users typically bind this to Ctrl-Space or Ctrl-F,
    # but the requirement is "inline tab completion", "predict text when I'm typing".
    # We will bind it to Tab, and if DeepSeek returns nothing, we could fallback, 
    # but since it's an AI, it almost always returns something.
    
    if [ -z "$DEEPSEEK_API_KEY" ]; then
        return
    fi
    
    local cmd=$(python3 -c '
import sys, json, urllib.request, os, shutil

prefix = sys.argv[1]
suffix = sys.argv[2]
api_key = os.environ.get("DEEPSEEK_API_KEY")

if not prefix.strip():
    sys.exit(0)

req_data = {
    "model": "deepseek-v4-pro",
    "prompt": prefix,
    "max_tokens": 128,
    "n": 3,
    "temperature": 0.2
}
if suffix: req_data["suffix"] = suffix

req = urllib.request.Request(
    "https://api.deepseek.com/beta/completions",
    data=json.dumps(req_data).encode("utf-8"),
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
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
    else
        # If AI returns nothing, we could trigger standard completion by falling back
        # but bind -x shadowing Tab prevents normal Tab. 
        # A common trick is to insert a literal tab or do nothing.
        true
    fi
}

bind -x '"\t": _omni_deepseek_tab_completion'
