#!/usr/bin/env python3
import argparse, json, os, shlex, subprocess, sys

def ancestors(pid):
    out=[]
    while pid and pid>1 and pid not in out:
        out.append(pid)
        try:
            with open(f"/proc/{pid}/stat") as f: pid=int(f.read().split()[3])
        except Exception: break
    return out

def focus_pid(pid):
    if not pid or not shutil_which("hyprctl"): return False
    try:
        clients=json.loads(subprocess.check_output(["hyprctl","clients","-j"],text=True,timeout=3))
        chain=ancestors(pid)
        for c in clients:
            cp=int(c.get("pid") or 0)
            if cp in chain:
                subprocess.run(["hyprctl","dispatch","focuswindow",f"address:{c.get('address')}"] ,timeout=3)
                return True
    except Exception: pass
    return False

def shutil_which(name):
    from shutil import which
    return which(name)

def terminal_run(terminal, command):
    argv=shlex.split(terminal or "kitty -e")
    subprocess.Popen(argv+["bash","-lc",command],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

def resume(args):
    if focus_pid(args.pid): return
    cmd="exec codex resume "+shlex.quote(args.session)
    if args.project: cmd="cd "+shlex.quote(args.project)+" && "+cmd
    terminal_run(args.terminal,cmd)

def launch(args):
    cmd=["codex","-C",args.project]
    if args.model: cmd += ["-m",args.model]
    perm=args.permission or ""
    if perm.startswith(":"): perm=perm[1:]
    if perm in ("read-only","workspace-write","danger-full-access"): cmd += ["-s",perm]
    elif perm=="workspace": cmd += ["-s","workspace-write"]
    if args.prompt: cmd += [args.prompt]
    terminal_run(args.terminal,"exec "+" ".join(shlex.quote(x) for x in cmd))

def notify(args):
    if not shutil_which("notify-send"): return
    cmd=["notify-send","-a","Codex","--action=open=Open","Codex — "+(args.title or "session"),"L'agent attend votre réponse."]
    try:
        result=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,timeout=86400)
        if result.stdout.strip()=="open": resume(args)
    except Exception: pass

def main():
    ap=argparse.ArgumentParser(); sub=ap.add_subparsers(dest="action",required=True)
    for name in ("resume","notify"):
        p=sub.add_parser(name); p.add_argument("--session",required=True); p.add_argument("--project",default=""); p.add_argument("--pid",type=int,default=0); p.add_argument("--terminal",default="kitty -e"); p.add_argument("--title",default="")
    p=sub.add_parser("launch"); p.add_argument("--project",required=True); p.add_argument("--prompt",default=""); p.add_argument("--model",default=""); p.add_argument("--permission",default=""); p.add_argument("--terminal",default="kitty -e")
    args=ap.parse_args(); {"resume":resume,"notify":notify,"launch":launch}[args.action](args)
if __name__=="__main__": main()
