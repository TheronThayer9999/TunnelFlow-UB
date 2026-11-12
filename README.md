# TunnelFlow-UB

Run **Ollama** on Google Colab and expose it to the internet with a **Bore** tunnel — one run and you get a public
`http://bore.pub:<PORT>` endpoint you can call from anywhere.

## Quick start

1. Open the notebook in Colab:

   ```
   https://colab.research.google.com/github/TheronThayer9999/TunnelFlow-UB/blob/master/TunnelFlow-UB.ipynb
   ```

2. **Runtime → Run all** (`Ctrl+F9`).
3. Copy the `http://bore.pub:<PORT>` URL printed by cell 1 and start using it.

## Files

| File | Purpose |
|---|---|
| `TunnelFlow-UB.ipynb` | Main notebook: installs Bore + Ollama, opens the tunnel, verifies it, pulls `tranhuythang9999/deepseek-v4-pro-9b-heretic:probe`, ships runnable sample clients (Python + curl) and an optional SSH cell |
| `script_tunnel.sh` | Plain `%%bash` cell with the same Ollama + tunnel setup |
| `script_ssh.sh` | SSH server on port 22 plus a second Bore tunnel for `ssh -p <PORT> root@bore.pub` |

## Fixed: wrong port printed by the old script

Bore v0.6.0 logs with a timestamp, so the old extraction grabbed the **year** instead of the port:

```text
log line : 2026-11-12T09:41:07.123Z  INFO bore_cli::client: listening at bore.pub:41234
old code : grep -o '[0-9]\{4,5\}' | head -n 1              -> 2026   (WRONG)
new code : grep -oE 'bore\.pub:[0-9]{1,5}' | sed 's/.*://' -> 41234  (correct)
```

Other fixes in this repo:

- no more fixed `sleep 4`: the script waits up to 30 s for the port to appear (Colab can be slow);
- the port is **verified with `curl`** through `bore.pub` before it is printed;
- ANSI colour codes and `\r` are stripped from the log before parsing;
- `set -e` no longer kills the script silently when the log has no match;
- tunnel cleanup is per-port (`pkill -f "bore local 11434 --to"`), so opening the SSH tunnel no longer kills the Ollama
  tunnel (and vice versa).

## Calling the endpoint

```bash
curl http://bore.pub:<PORT>/api/tags

curl http://bore.pub:<PORT>/api/generate \
  -d '{"model":"tranhuythang9999/deepseek-v4-pro-9b-heretic:probe","prompt":"hello","stream":false}'
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://bore.pub:<PORT>/v1", api_key="ollama")
print(client.chat.completions.create(
    model="tranhuythang9999/deepseek-v4-pro-9b-heretic:probe",
    messages=[{"role": "user", "content": "Hello!"}],
).choices[0].message.content)
```

## Notes

- A free Colab runtime stops after ~12 h or when idle for a while → re-run the notebook, the port changes.
- Free `bore.pub` assigns a **random** port each run. Pass `--port <n>` to `bore local` if you need a fixed one.
- The SSH cell publishes `root` with a plain password (`MySecurePass123` by default) to the public internet — change it
  or leave `ENABLE_SSH=0`.
