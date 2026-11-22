# Usage

Stade runs each script as a launch agent. A script is a name, a command, and a
working directory; launchd starts the command in the background and keeps the
process alive according to the two toggles.

## How a script runs

| Field | Meaning |
| --- | --- |
| Name | Agent name; lowercase letters, digits, `-`, `_` |
| Command | Shell command, run as `/bin/zsh -l -i -c <command>` |
| Directory | Absolute working directory; launchd does not expand `~` |
| Start at login | Load and run the agent when you log in |
| Restart on crash | Relaunch after a non-zero exit; a clean exit stays stopped |

The command must stay in the foreground. Do not add `&`, `nohup`, or a daemon
flag: the shell would exit, launchd would see a finished process, and
restart-on-crash would relaunch it in a loop. Stade adds `exec` to simple
commands automatically so launchd tracks the real process.

Output goes to `~/Library/Logs/Stade/<name>.log`; use **Logs** in the app to
read it. The viewer follows new output, can pause and search, and **Open in
Editor** opens the full file in your default text editor. **Stop** disables the
agent and unloads it, so it stays stopped across logins until you press
**Start**. Removing a script keeps its log.

## Serve a PHP app on one port

Use the PHP built-in server when you want a small app or API reachable at one
local address.

| Field | Value |
| --- | --- |
| Name | `php-app` |
| Command | `php -S 127.0.0.1:8080` |
| Directory | `/Users/you/Code/hello-php` |
| Start at login | On |
| Restart on crash | On |

The server listens on port 8080 and stays in the foreground, which is exactly
what launchd supervises. Check it with `curl http://127.0.0.1:8080/`. Binding
`127.0.0.1` keeps it local to this Mac; use `0.0.0.0` only when you intend to
expose it to the network. The built-in server is single-threaded and meant for
development, not production traffic.

If `php` is not found, install PHP or put its absolute path in the command
(`/opt/homebrew/bin/php -S 127.0.0.1:8080`). If the port is already taken, the
log shows `Address already in use`; find the owner with
`lsof -nP -iTCP:8080 -sTCP:LISTEN`, then stop it or pick another port.

## Run a background worker

Long-running consumers — queue workers, pollers, WebSocket bridges — are a
better fit than cron jobs when they must stay connected between jobs.

| Field | Value |
| --- | --- |
| Name | `queue-worker` |
| Command | `node worker.js` |
| Directory | `/Users/you/Code/my-app` |
| Start at login | On |
| Restart on crash | On |

Restart-on-crash covers crashes and dropped connections; a clean exit stays
stopped, so a worker that finishes its work is not relaunched forever. Worker
frameworks that run in the foreground work unchanged; remove any daemon flag
from their commands.
