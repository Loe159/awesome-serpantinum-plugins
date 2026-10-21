#!/usr/bin/env python3
"""Todoist API v1 bridge for the Serpantinum QML plugin.

No third-party Python modules. OAuth credentials are kept in the desktop
Secret Service; no access/refresh token is written to disk or QML.
"""
import base64
import datetime as dt
import hashlib
import http.server
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen
import uuid

API = "https://api.todoist.com/api/v1"
OAUTH = "https://api.todoist.com/oauth"
APP = "serpantinum-todoist"
SCOPE = "data:read_write"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / APP
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / APP
AUTH_MARK = STATE_DIR / "authorizing.json"
NOTIFIED = STATE_DIR / "notified.json"
CACHE = CACHE_DIR / "snapshot.json"
AUTH_ERR = STATE_DIR / "auth-error.json"


class TodoistError(Exception):
    pass


def write_private(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(path.parent, 0o700)
    tmp = path.with_suffix(path.suffix + ".tmp." + secrets.token_hex(5))
    with open(tmp, "x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def read_json(path, default=None):
    try:
        with path.open(encoding="utf-8") as stream:
            return json.load(stream)
    except (OSError, ValueError, TypeError):
        return default


def secret_read():
    if not shutil.which("secret-tool"):
        raise TodoistError("secret-tool (libsecret) est nécessaire pour la connexion sécurisée.")
    proc = subprocess.run(
        ["secret-tool", "lookup", "application", APP, "kind", "oauth"],
        capture_output=True, text=True, timeout=8, check=False,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        return json.loads(proc.stdout)
    except ValueError:
        return None


def secret_save(value):
    if not shutil.which("secret-tool"):
        raise TodoistError("Installez libsecret / secret-tool pour protéger la connexion.")
    proc = subprocess.run(
        ["secret-tool", "store", "--label=Serpantinum Todoist", "application", APP, "kind", "oauth"],
        input=json.dumps(value), text=True, capture_output=True, timeout=30, check=False,
    )
    if proc.returncode:
        raise TodoistError("Impossible d'enregistrer les identifiants dans le trousseau Linux.")


def secret_clear():
    if shutil.which("secret-tool"):
        subprocess.run(
            ["secret-tool", "clear", "application", APP, "kind", "oauth"],
            capture_output=True, timeout=8, check=False,
        )


def request(url, method="GET", body=None, token=None, form=False, request_id=None):
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if request_id:
        headers["X-Request-Id"] = request_id
    data = None
    if body is not None:
        if form:
            data = urlencode(body).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=15) as response:
            raw = response.read(8 * 1024 * 1024)
            return json.loads(raw) if raw else {}
    except HTTPError as exc:
        if exc.code == 401:
            raise TodoistError("Session Todoist expirée.") from exc
        if exc.code == 429:
            raise TodoistError("Limite Todoist atteinte, réessayez plus tard.") from exc
        raise TodoistError("Erreur Todoist HTTP " + str(exc.code)) from exc
    except (URLError, TimeoutError) as exc:
        raise TodoistError("Réseau Todoist indisponible.") from exc


def token_for(credentials):
    if not credentials:
        raise TodoistError("Connectez votre compte Todoist.")
    expiry = float(credentials.get("expires_at", 0))
    if expiry and expiry < time.time() + 90:
        refresh = credentials.get("refresh_token")
        if not refresh:
            raise TodoistError("Session expirée. Reconnectez Todoist.")
        result = request(OAUTH + "/access_token", "POST", {
            "client_id": credentials["client_id"],
            "grant_type": "refresh_token",
            "refresh_token": refresh,
        }, form=True)
        credentials["access_token"] = result["access_token"]
        credentials["refresh_token"] = result.get("refresh_token", refresh)
        credentials["expires_at"] = time.time() + int(result.get("expires_in", 3600))
        # Save the rotated refresh token before using the new access token.
        secret_save(credentials)
    return credentials["access_token"]


def all_pages(path, token):
    results = []
    cursor = ""
    for _ in range(100):
        url = API + path
        if cursor:
            url += ("&" if "?" in url else "?") + urlencode({"cursor": cursor})
        response = request(url, token=token)
        if isinstance(response, list):
            results.extend(response)
            break
        results.extend(response.get("results", []))
        cursor = response.get("next_cursor")
        if not cursor:
            break
    else:
        raise TodoistError("Trop de pages Todoist, actualisation interrompue.")
    return results


def due_info(task, now):
    due = task.get("due") or {}
    date_string = due.get("date") or ""
    datetime_string = due.get("datetime")
    instant = None
    if not datetime_string and "T" in date_string:
        datetime_string = date_string
    if datetime_string:
        try:
            instant = dt.datetime.fromisoformat(datetime_string.replace("Z", "+00:00"))
            if instant.tzinfo is None:
                instant = instant.replace(tzinfo=now.tzinfo)
            instant = instant.astimezone()
            date_string = instant.date().isoformat()
        except ValueError:
            instant = None
    due_date = None
    try:
        due_date = dt.date.fromisoformat(date_string[:10])
    except ValueError:
        pass
    overdue = (instant < now) if instant else (due_date < now.date() if due_date else False)
    label = ""
    if due_date:
        if due_date == now.date():
            label = "Aujourd'hui"
        elif due_date == now.date() + dt.timedelta(days=1):
            label = "Demain"
        else:
            label = due_date.strftime("%d/%m")
    if instant:
        label += " · " + instant.strftime("%H:%M")
    return {
        "dueDate": due_date.isoformat() if due_date else "",
        "dueDatetime": instant.isoformat() if instant else "",
        "dueLabel": label,
        "overdue": overdue,
        "today": due_date == now.date() if due_date else False,
    }


def normalize(tasks, projects):
    now = dt.datetime.now().astimezone()
    output = []
    project_map = {str(p.get("id")): p for p in projects}
    for task in tasks:
        if task.get("checked") or task.get("is_deleted"):
            continue
        pid = str(task.get("project_id", ""))
        project = project_map.get(pid, {})
        output.append({
            "id": str(task["id"]),
            "content": task.get("content", ""),
            "description": task.get("description", ""),
            "projectId": pid,
            "projectName": project.get("name", ""),
            "projectColor": project.get("color", "grey"),
            "inbox": bool(project.get("is_inbox_project")),
            "priority": int(task.get("priority") or 4),
            "recurring": bool((task.get("due") or {}).get("is_recurring")),
            "dueString": (task.get("due") or {}).get("string") or "",
            **due_info(task, now),
        })
    output.sort(key=lambda t: (t["dueDate"] or "9999", t["dueDatetime"] or "", t["priority"], t["content"].lower()))
    return output


def maybe_notify(tasks, options):
    if not shutil.which("notify-send"):
        return
    before = max(0, min(1440, int(options.get("reminderMinutes", 30))))
    warn_soon = bool(options.get("notifyDue", True))
    warn_late = bool(options.get("notifyOverdue", True))
    now = dt.datetime.now().astimezone()
    history = read_json(NOTIFIED, {})
    # Avoid unbounded state growth.
    if len(history) > 2000:
        history = dict(list(history.items())[-500:])
    changed = False
    for task in tasks:
        if not task["dueDate"]:
            continue
        kind = ""
        key = ""
        if warn_late and task["overdue"]:
            kind = "Tâche en retard"
            key = task["id"] + ":late:" + (task["dueDatetime"] or task["dueDate"])
        elif warn_soon and task["dueDatetime"]:
            due = dt.datetime.fromisoformat(task["dueDatetime"])
            delta = (due - now).total_seconds()
            if 0 <= delta <= before * 60:
                kind = "Échéance proche"
                key = task["id"] + ":soon:" + task["dueDatetime"]
        if not key or key in history:
            continue
        # Preserve notification deduplication across restarts.
        history[key] = int(time.time())
        changed = True
        try:
            subprocess.Popen(
                ["notify-send", "-a", "Todoist", "-i", str(Path(__file__).resolve().parent.parent / "assets/todoist.svg"), kind, task["content"]],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except OSError:
            pass
    if changed:
        write_private(NOTIFIED, history)


def status(options):
    credentials = secret_read()
    pending = read_json(AUTH_MARK, {})
    authorizing = bool(pending and time.time() - pending.get("started", 0) < 190)
    snapshot = read_json(CACHE, {})
    if not credentials:
        error = (read_json(AUTH_ERR, {}) or {}).get("error", "")
        return {"connected": False, "authorizing": authorizing, "tasks": [], "projects": [],
                "error": error or ("" if shutil.which("secret-tool") else "Installez secret-tool (libsecret).")}
    try:
        token = token_for(credentials)
        tasks = all_pages("/tasks", token)
        projects = all_pages("/projects", token)
        active = normalize(tasks, projects)
        snapshot = {"tasks": active, "projects": projects, "syncedAt": int(time.time())}
        write_private(CACHE, snapshot)
        maybe_notify(active, options)
        return {"connected": True, "authorizing": False, "stale": False, "error": "", **snapshot}
    except (TodoistError, OSError, ValueError, KeyError) as exc:
        return {"connected": True, "authorizing": authorizing, "stale": True,
                "error": str(exc), **(snapshot or {"tasks": [], "projects": []})}


def login():
    if secret_read():
        return {"ok": True, "message": "Déjà connecté."}
    AUTH_ERR.unlink(missing_ok=True)
    write_private(AUTH_MARK, {"started": time.time()})
    # The HTTP listener is loopback-only; the OAuth redirect must match exactly.
    try:
        server = http.server.HTTPServer(("127.0.0.1", 0), http.server.BaseHTTPRequestHandler)
        port = server.server_address[1]
        redirect_uri = "http://localhost:" + str(port) + "/callback"
        client = request(OAUTH + "/register", "POST", {
            "client_name": "Serpantinum Todoist",
            "redirect_uris": [redirect_uri],
            "scope": SCOPE,
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
        })
    except (TodoistError, OSError, KeyError, ValueError) as exc:
        write_private(AUTH_ERR, {"error": str(exc)})
        AUTH_MARK.unlink(missing_ok=True)
        if "server" in locals():
            server.server_close()
        raise
    client_id = client["client_id"]
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(32)
    outcome = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            params = parse_qs(urlparse(self.path).query)
            valid = urlparse(self.path).path == "/callback" and params.get("state", [""])[0] == state
            if valid:
                outcome["code"] = params.get("code", [""])[0]
                outcome["error"] = params.get("error", [""])[0]
            response = "Vous pouvez fermer cette page." if valid else "Lien de connexion non valide."
            data = ("<html><meta charset='utf-8'><body><h3>" + response + "</h3></body></html>").encode()
            self.send_response(200 if valid else 400)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass

    server.RequestHandlerClass = Handler
    url = "https://app.todoist.com/oauth/authorize?" + urlencode({
        "client_id": client_id, "scope": SCOPE, "state": state, "response_type": "code",
        "redirect_uri": redirect_uri, "code_challenge": challenge, "code_challenge_method": "S256",
    })
    try:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        server.timeout = 1
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline and not outcome:
            server.handle_request()
        if not outcome.get("code"):
            raise TodoistError("Connexion refusée ou délai expiré.")
        result = request(OAUTH + "/access_token", "POST", {
            "client_id": client_id, "code": outcome["code"],
            "redirect_uri": redirect_uri, "code_verifier": verifier,
            "grant_type": "authorization_code",
        }, form=True)
        secret_save({
            "client_id": client_id, "access_token": result["access_token"],
            "refresh_token": result.get("refresh_token", ""),
            "expires_at": time.time() + int(result.get("expires_in", 3600)),
        })
        return {"ok": True}
    except (TodoistError, OSError, KeyError, ValueError) as exc:
        write_private(AUTH_ERR, {"error": str(exc)})
        raise
    finally:
        server.server_close()
        AUTH_MARK.unlink(missing_ok=True)


def mutate(op, values):
    token = token_for(secret_read())
    rid = str(uuid.uuid4())
    task_id = str(values.get("id", ""))
    if op == "quick":
        text = str(values.get("text", "")).strip()
        if not text:
            raise TodoistError("Saisissez une tâche.")
        result = request(API + "/tasks/quick", "POST", {"text": text}, token=token, request_id=rid)
    elif op == "create":
        content = str(values.get("content", "")).strip()
        if not content:
            raise TodoistError("Le titre est obligatoire.")
        body = {"content": content, "description": values.get("description", ""),
                "priority": int(values.get("priority", 4))}
        if values.get("project_id"):
            body["project_id"] = values["project_id"]
        if values.get("due_string"):
            body["due_string"] = values["due_string"]
        result = request(API + "/tasks", "POST", body, token=token, request_id=rid)
    elif op in ("update", "move", "close", "reopen"):
        if not task_id or "/" in task_id:
            raise TodoistError("Identifiant de tâche invalide.")
        path = API + "/tasks/" + task_id
        if op == "update":
            allowed = {"content", "description", "priority", "due_string", "due_date", "due_datetime"}
            body = {k: v for k, v in values.items() if k in allowed}
            if not body:
                raise TodoistError("Aucune modification.")
            result = request(path, "POST", body, token=token, request_id=rid)
        elif op == "move":
            if not values.get("project_id"):
                raise TodoistError("Choisissez un projet.")
            result = request(path + "/move", "POST", {"project_id": values["project_id"]},
                             token=token, request_id=rid)
        else:
            result = request(path + "/" + op, "POST", token=token, request_id=rid)
    else:
        raise TodoistError("Action inconnue.")
    return {"ok": True, "result": result if isinstance(result, dict) else {}}


def main():
    op = sys.argv[1] if len(sys.argv) > 1 else "status"
    values = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    if op == "status":
        return status(values)
    if op == "auth-status":
        creds = secret_read()
        pending = read_json(AUTH_MARK, {})
        return {"connected": bool(creds),
                "authorizing": bool(pending and time.time() - pending.get("started", 0) < 190),
                "error": (read_json(AUTH_ERR, {}) or {}).get("error", "") if not creds else ""}
    if op == "login":
        return login()
    if op == "logout":
        secret_clear()
        CACHE.unlink(missing_ok=True)
        AUTH_ERR.unlink(missing_ok=True)
        AUTH_MARK.unlink(missing_ok=True)
        NOTIFIED.unlink(missing_ok=True)
        return {"ok": True}
    return mutate(op, values)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (TodoistError, OSError, ValueError, KeyError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        sys.exit(1)
