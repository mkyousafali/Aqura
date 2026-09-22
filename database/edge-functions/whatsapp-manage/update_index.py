import json
# Read from stdin and write to index.ts
content = ""
while True:
    try:
        line = input()
        content += line + "\n"
    except EOFError:
        break
with open("index.ts", "w") as f:
    f.write(content)
print(f"✅ File written: {len(content)} chars")
