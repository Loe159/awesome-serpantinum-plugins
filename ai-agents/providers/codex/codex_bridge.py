#!/usr/bin/env python3
"""Local Codex app-server bridge for the Serpantinum AI Agents plugin."""
import argparse, json, os, pathlib, queue, select, shlex, subprocess, sys, threading, time

HOME = pathlib.Path.home()
CODEX = os.environ.get("CODEX_BIN", "codex")
CLIENT = {"name": "serpantinum-ai-agents", "version": "0.1.0"}

class Rpc:
    def __init__(self):
        self.proc = subprocess.Popen([CODEX, "app-server", "--listen", "stdio://"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        self.next_id = 1
        self.pending = {}
        self.events = queue.Queue()
        self.lock = threading.Lock()
        threading.Thread(target=self._reader, daemon=True).start()
        self.call("initialize", {"clientInfo": CLIENT, "capabilities": {"experimentalApi": True}}, 10)
        self.send({"method": "initialized"})

    def send(self, obj):
        with self.lock:
            self.proc.stdin.write(json.dumps(obj, separators=(",", ":")) + "\n")
            self.proc.stdin.flush()

    def call(self, method, params=None, timeout=15):
        rid = self.next_id; self.next_id += 1
        q = queue.Queue(1); self.pending[str(rid)] = q
        self.send({"id": rid, "method": method, "params": {} if params is None else params})
        msg = q.get(timeout=timeout)
        if "error" in msg: raise RuntimeError(msg["error"])
        return msg.get("result")

    def _reader(self):
        for line in self.proc.stdout:
            try: msg = json.loads(line)
            except Exception: continue
            if "id" in msg and str(msg["id"]) in self.pending:
                self.pending.pop(str(msg["id"])).put(msg)
            else: self.events.put(msg)

    def close(self):
        try: self.proc.terminate()
        except Exception: pass

def status_of(thread):
    st = thread.get("status") or {}
    typ = st.get("type", "idle") if isinstance(st, dict) else str(st)
    flags = st.get("activeFlags", []) if isinstance(st, dict) else []
    if typ == "systemError": return "Failed"
    if typ == "active" and any(x in flags for x in ("waitingOnApproval", "waitingOnUserInput")): return "Waiting"
    if typ == "active": return "Working"
    return "Idle"

def title_of(t):
    name = (t.get("name") or "").strip()
    if name: return name
    cwd = (t.get("cwd") or "").rstrip("/")
    if cwd: return pathlib.Path(cwd).name or cwd
    preview = " ".join((t.get("preview") or "").split())
    return preview[:72] or "Codex session"

def last_message(rpc, thread_id):
    try:
        r = rpc.call("thread/read", {"threadId": thread_id, "includeTurns": True}, 8) or {}
        thread = r.get("thread", r)
        for turn in reversed(thread.get("turns") or []):
            for item in reversed(turn.get("items") or []):
                if item.get("type") == "agentMessage" and item.get("text"):
                    return " ".join(item["text"].split())[:600]
    except Exception: pass
    return ""

def process_candidates():
    out=[]
    try:
        raw=subprocess.check_output(["ps","-u",str(os.getuid()),"-o","pid=,ppid=,etimes=,args="], text=True, timeout=3)
        for line in raw.splitlines():
            parts=line.strip().split(None,3)
            if len(parts)<4: continue
            pid,ppid,etimes,args=parts
            if "codex" not in args.lower() or "codex_bridge.py" in args or "app-server" in args: continue
            try: cwd=os.readlink(f"/proc/{pid}/cwd")
            except OSError: cwd=""
            out.append({"pid":int(pid),"ppid":int(ppid),"elapsed":int(etimes),"args":args,"cwd":cwd})
    except Exception: pass
    return out

def attach_process(session, processes):
    cwd=session.get("projectPath") or ""
    sid=session.get("id") or ""
    exact=[p for p in processes if sid and sid in p["args"]]
    matches=exact or [p for p in processes if cwd and p["cwd"]==cwd]
    if len(matches)==1:
        session["processId"]=matches[0]["pid"]
    return session

def quota_items(rate):
    snap=(rate or {}).get("rateLimits") or {}
    result=[]
    for key,label in (("primary","5h"),("secondary","Weekly")):
        w=snap.get(key)
        if not w: continue
        result.append({"id":key,"label":label,"remainingPercent":max(0,100-int(w.get("usedPercent",0))),"resetsAt":w.get("resetsAt"),"windowDurationMins":w.get("windowDurationMins")})
    return result

def snapshot(rpc, recent_count=10, with_messages=True):
    res=rpc.call("thread/list", {"limit": max(30,recent_count*3), "sortKey":"recency_at", "sortDirection":"desc"}, 15) or {}
    threads=res.get("data") or []
    processes=process_candidates(); active=[]; recent=[]; claimed_pids=set()
    for t in threads:
        state=status_of(t)
        s={"id":t.get("id", ""),"provider":"codex","title":title_of(t),"projectName":pathlib.Path((t.get("cwd") or "").rstrip("/")).name,"projectPath":t.get("cwd") or "","model":t.get("model") or "","state":state,"startedAt":t.get("createdAt"),"updatedAt":t.get("updatedAt"),"lastMessage":"","processId":0,"terminalWindowId":"","resumable":True}
        attach_process(s,processes)
        if state == "Idle" and s.get("processId") and s["processId"] not in claimed_pids:
            state = s["state"] = "Working"
            claimed_pids.add(s["processId"])
        elif s.get("processId") in claimed_pids:
            s["processId"] = 0
        if state in ("Working","Waiting"):
            if with_messages: s["lastMessage"]=last_message(rpc,s["id"])
            active.append(s)
        elif len(recent)<recent_count:
            if with_messages: s["lastMessage"]=last_message(rpc,s["id"])
            recent.append(s)
    try: rate=rpc.call("account/rateLimits/read", {"excludeResetCreditDetails":True}, 12)
    except Exception: rate={}
    try:
        models=(rpc.call("model/list", {"limit":100,"includeHidden":False}, 12) or {}).get("data",[])
        models=[{"id":m.get("model") or m.get("id"),"name":m.get("displayName") or m.get("model") or m.get("id"),"isDefault":bool(m.get("isDefault"))} for m in models if not m.get("hidden")]
    except Exception: models=[]
    cwd=(active[0]["projectPath"] if active else (recent[0]["projectPath"] if recent else str(HOME)))
    try:
        perms=(rpc.call("permissionProfile/list", {"cwd":cwd,"limit":100}, 12) or {}).get("data",[])
        perms=[p for p in perms if p.get("allowed",True)]
    except Exception: perms=[]
    projects=[]
    for s in active+recent:
        if s["projectPath"] and s["projectPath"] not in [p["path"] for p in projects]: projects.append({"name":s["projectName"],"path":s["projectPath"]})
    return {"type":"snapshot","activeSessions":active,"recentSessions":recent[:recent_count],"quotaItems":quota_items(rate),"availableModels":models,"availablePermissions":perms,"recentProjects":projects[:12],"timestamp":int(time.time())}

def emit(obj):
    print(json.dumps(obj,separators=(",",":"),ensure_ascii=False),flush=True)

def monitor(args):
    rpc=Rpc(); last_states={}; last_full=0
    try:
        snap=snapshot(rpc,args.recent,True); emit(snap); last_full=time.time()
        last_states={s["id"]:s["state"] for s in snap["activeSessions"]+snap["recentSessions"]}
        while True:
            changed=False
            try:
                msg=rpc.events.get(timeout=1)
                method=msg.get("method","")
                if method.startswith("thread/") or method.startswith("item/") or method=="account/rateLimits/updated": changed=True
            except queue.Empty: pass
            interval=30 if any(v in ("Working","Waiting") for v in last_states.values()) else 300
            if changed or time.time()-last_full>=interval:
                snap=snapshot(rpc,args.recent,changed)
                states={s["id"]:s["state"] for s in snap["activeSessions"]+snap["recentSessions"]}
                for s in snap["activeSessions"]:
                    if s["state"]=="Waiting" and last_states.get(s["id"]) not in (None,"Waiting"):
                        emit({"type":"attention","session":s})
                emit(snap); last_states=states; last_full=time.time()
    finally: rpc.close()

def once(args):
    rpc=Rpc()
    try: emit(snapshot(rpc,args.recent,True))
    finally: rpc.close()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--once",action="store_true"); ap.add_argument("--recent",type=int,default=10); args=ap.parse_args()
    try: once(args) if args.once else monitor(args)
    except Exception as e: emit({"type":"error","message":str(e)}); sys.exit(1)
if __name__=="__main__": main()
