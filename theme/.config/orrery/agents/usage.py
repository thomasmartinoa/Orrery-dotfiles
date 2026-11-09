#!/usr/bin/env python3
"""orrery-agent usage-update: collect coding-agent usage into one JSON file.

Writes ~/.local/state/orrery/agents.json:
  {
    "updated": <epoch>,
    "accounts": [ { id, name, plan, url, note, warn, error, providerDetail,
                    limits: [ {name, percent, resets_at, elapsed?} ],
                    extra: {enabled, used, limit} | null,
                    stats: [ {label, value, kind} x3 ] } ],
    "tokensByAgent": { <id>: { days: [ {date, total, output} x7 ],
                               models: [ {model, total, output} ], messages, sessions } },
    "tokens": <Claude's, for older readers>
  }

An agent appears when its command is on PATH and goes when it is removed. Quotas
come from the agent's own service (Claude: the account usage endpoint; OpenCode:
OpenRouter's key endpoint; Codex: the rate limits it logs locally); token counts
are always read from the agent's local logs. Credential files are only read,
never written: if a token has expired the account says so, and running the
agent once refreshes it. To add an agent: write a function that returns its
tokens (use Tally) and add a block to main().
"""
import glob, json, os, shutil, sqlite3, sys, time, urllib.request
from datetime import datetime, timedelta, timezone

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local/state/orrery")
OUT = os.path.join(STATE, "agents.json")


# ---------------------------------------------------------------- Claude Code
def claude():
    cred = os.path.join(HOME, ".claude/.credentials.json")
    if not os.path.exists(cred):
        return None
    acct = {"id": "claude", "name": "Claude Code", "plan": "", "limits": [], "extra": None, "error": "",
            "url": "https://claude.ai/settings/usage"}
    try:
        oauth = json.load(open(cred)).get("claudeAiOauth") or {}
    except (OSError, ValueError) as e:
        acct["error"] = f"credentials unreadable: {e}"
        return acct
    plan = oauth.get("subscriptionType") or ""
    acct["plan"] = {"pro": "Pro", "max": "Max", "team": "Team", "enterprise": "Enterprise"}.get(plan, plan.title())
    token = oauth.get("accessToken")
    if not token:
        acct["error"] = "not logged in — run claude"
        return acct
    if oauth.get("expiresAt", 0) / 1000 < time.time():
        acct["error"] = "token expired — run claude once to refresh"
        return acct
    req = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={"Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20",
                 "Accept": "application/json", "User-Agent": "orrery-agent"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.load(r)
    except Exception as e:  # network, 401, 429, …
        code = getattr(e, "code", None)
        acct["error"] = ("Usage is rate-limited for a moment; it refreshes on its own" if code == 429
                         else "Sign-in expired: run claude once to refresh it" if code in (401, 403)
                         else f"Couldn't reach the usage service ({code})" if code
                         else "Couldn't reach the usage service (offline?)")
        return acct
    windows = {"five_hour": 5 * 3600, "seven_day": 7 * 86400}
    names = {"five_hour": "Session (5h)", "seven_day": "Weekly", "seven_day_opus": "Weekly · Opus",
             "seven_day_sonnet": "Weekly · Sonnet", "seven_day_oauth_apps": "Weekly · apps"}
    for key, label in names.items():
        v = d.get(key)
        if isinstance(v, dict) and v.get("utilization") is not None:
            lim = {"name": label, "percent": round(v["utilization"]), "resets_at": v.get("resets_at") or ""}
            if key in windows and lim["resets_at"]:
                try:   # how far through the window we are, for the pace tick
                    left = datetime.fromisoformat(lim["resets_at"]).timestamp() - time.time()
                    lim["elapsed"] = max(0, min(100, round(100 * (1 - left / windows[key]))))
                except ValueError:
                    pass
            acct["limits"].append(lim)
    first = acct["limits"][0] if acct["limits"] else None
    if first and "elapsed" in first:
        acct["note"] = ("Using the session faster than time passes: ease off"
                        if first["percent"] >= first["elapsed"] + 15 and first["percent"] >= 50
                        else "Session just started" if first["elapsed"] < 5
                        else f"On pace: {first['percent']}% used, {first['elapsed']}% of the window gone")
    x = d.get("extra_usage") or {}
    if not x.get("is_enabled"):
        acct["providerDetail"] = "Extra usage is off"
    if x.get("is_enabled"):
        acct["extra"] = {"enabled": True, "used": x.get("used_credits"), "limit": x.get("monthly_limit"),
                         "percent": x.get("utilization"), "currency": x.get("currency") or "USD"}
    return acct



class Tally:
    """Tokens by day and by model, plus message/session counts, for one agent."""
    def __init__(self, days=7):
        self.n, self.by_day, self.by_model, self.sessions, self.messages = days, {}, {}, set(), 0
        self.since = datetime.now(timezone.utc) - timedelta(days=days)

    def add(self, t, total, out, model, session=None):
        if t < self.since or not total:
            return
        day = t.astimezone().strftime("%Y-%m-%d")
        dd = self.by_day.setdefault(day, {"date": day, "total": 0, "output": 0})
        dd["total"] += total; dd["output"] += out
        mm = self.by_model.setdefault(model, {"model": model, "total": 0, "output": 0})
        mm["total"] += total; mm["output"] += out
        self.messages += 1
        if session:
            self.sessions.add(session)

    def result(self):
        today = datetime.now().date()
        days = []
        for i in range(self.n - 1, -1, -1):
            d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
            days.append(self.by_day.get(d, {"date": d, "total": 0, "output": 0}))
        return {"days": days, "models": sorted(self.by_model.values(), key=lambda x: -x["total"]),
                "messages": self.messages, "sessions": len(self.sessions)}


def stats(tokens, cost=None):
    """Three small facts for the panel: today, messages, sessions (or cost)."""
    days = tokens.get("days") or []
    out = [{"label": "Today", "value": days[-1]["total"] if days else 0, "kind": "tokens"},
           {"label": "Replies", "value": tokens.get("messages", 0), "kind": "count"},
           {"label": "Sessions", "value": tokens.get("sessions", 0), "kind": "count"}]
    if cost:
        out[2] = {"label": "Cost 7d", "value": round(cost, 2), "kind": "usd"}
    return out


def installed(cmd):
    return shutil.which(cmd) is not None     # the same test orrery-agent list uses


# --------------------------------------------------- local token counts (Claude)
def claude_tokens(days=7):
    """Sum token usage from Claude Code's transcripts (~/.claude/projects).
    Streams are written as several lines per response sharing a requestId,
    so count each once."""
    tally, seen = Tally(days), set()
    for f in glob.glob(os.path.join(HOME, ".claude/projects/**/*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(f) < tally.since.timestamp():
                continue
            with open(f, "rb") as fh:
                for line in fh:
                    if b'"usage"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    m = e.get("message") or {}
                    u = m.get("usage")
                    if not u or e.get("type") != "assistant":
                        continue
                    key = e.get("requestId") or m.get("id")
                    if key in seen:
                        continue
                    seen.add(key)
                    model = (m.get("model") or "unknown").replace("claude-", "")
                    if model.startswith("<"):   # <synthetic>: no tokens
                        continue
                    try:
                        t = datetime.fromisoformat(e.get("timestamp", "").replace("Z", "+00:00"))
                    except ValueError:
                        continue
                    out = u.get("output_tokens", 0)
                    total = (u.get("input_tokens", 0) + out + u.get("cache_read_input_tokens", 0)
                             + u.get("cache_creation_input_tokens", 0))
                    tally.add(t, total, out, model, e.get("sessionId"))
        except OSError:
            continue
    return tally.result()


# ------------------------------------------------------------ OpenCode usage
OPENCODE_DB = os.path.join(HOME, ".local/share/opencode/opencode.db")


def opencode_tokens(days=7):
    """Read OpenCode's local SQLite message usage (never its credentials).
    Returns (tokens, cost, notice, providers)."""
    tally, cost, limit_until, providers = Tally(days), 0.0, 0, []
    try:
        db = sqlite3.connect("file:" + OPENCODE_DB + "?mode=ro", uri=True, timeout=2)
        since_ms = int(tally.since.timestamp() * 1000)
        rows = db.execute("SELECT time_created, session_id, data FROM session_message "
                          "WHERE type='assistant' AND time_created >= ? ORDER BY time_created", (since_ms,))
        for created, sid, raw in rows:
            try:
                msg = json.loads(raw)
                t = datetime.fromtimestamp((msg.get("time") or {}).get("created", created) / 1000, timezone.utc)
                err = msg.get("error") or {}
                if err.get("type") == "provider.free-limit":
                    limit_until = t.timestamp() + (err.get("retryAfterMs") or 0) / 1000
                elif not err:
                    limit_until = 0     # a later reply worked: the limit is over
                usage = msg.get("tokens") or {}
                out = int(usage.get("output", 0) or 0)
                cache = usage.get("cache") or {}
                total = (sum(int(usage.get(k, 0) or 0) for k in ("input", "output", "reasoning"))
                         + int(cache.get("read", 0) or 0) + int(cache.get("write", 0) or 0))
                cost += float(msg.get("cost") or 0)
                tally.add(t, total, out, (msg.get("model") or {}).get("id") or "unknown", sid)
            except (ValueError, TypeError, AttributeError):
                continue
        providers = [r[0] for r in db.execute("SELECT integration_id FROM credential WHERE active=1")]
        db.close()
    except (sqlite3.Error, OSError, ValueError, TypeError):
        pass
    left = limit_until - time.time()
    notice = (f"Free models rate-limited · back in {int(left // 3600)}h {int(left % 3600 // 60)}m"
              if left > 0 else "")
    return tally.result(), cost, notice, providers


# --------------------------------------------------------------- Codex usage
def codex_usage(days=7):
    """Codex writes one rollout file per session (~/.codex/sessions/**/rollout-*.jsonl).
    Its token_count events carry the tokens of that turn and the account's
    rate limits (5h and weekly windows), so everything is read locally.
    Returns (tokens, limits, plan)."""
    tally, limits, plan, newest = Tally(days), [], "", 0
    root = os.path.join(HOME, ".codex")
    for f in glob.glob(os.path.join(root, "sessions/**/rollout-*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(f) < tally.since.timestamp():
                continue
            model, sid = "codex", os.path.basename(f)
            with open(f, "rb") as fh:
                for line in fh:
                    if b'"turn_context"' in line:
                        try:
                            model = json.loads(line).get("payload", {}).get("model") or model
                        except ValueError:
                            pass
                        continue
                    if b'"token_count"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                        pl = e.get("payload") or {}
                        t = datetime.fromisoformat(e.get("timestamp", "").replace("Z", "+00:00"))
                    except (ValueError, AttributeError):
                        continue
                    last = (pl.get("info") or {}).get("last_token_usage") or {}
                    out = int(last.get("output_tokens", 0) or 0) + int(last.get("reasoning_output_tokens", 0) or 0)
                    tally.add(t, int(last.get("total_tokens", 0) or 0), out, model, sid)
                    rl = pl.get("rate_limits") or {}
                    if rl and t.timestamp() >= newest:
                        newest, plan = t.timestamp(), rl.get("plan_type") or plan
                        limits = []
                        for key, label in (("primary", "Session (5h)"), ("secondary", "Weekly")):
                            w = rl.get(key) or {}
                            if w.get("used_percent") is None:
                                continue
                            resets = w.get("resets_at")
                            if resets is None and w.get("resets_in_seconds") is not None:
                                resets = time.time() + w["resets_in_seconds"]
                            lim = {"name": "Weekly" if (w.get("window_minutes") or 0) >= 10080 else label,
                                   "percent": round(w["used_percent"]),
                                   "resets_at": datetime.fromtimestamp(resets, timezone.utc).isoformat() if resets else ""}
                            limits.append(lim)
        except OSError:
            continue
    # a limit that already reset is not "used" any more
    limits = [l for l in limits if not l["resets_at"] or datetime.fromisoformat(l["resets_at"]).timestamp() > time.time()]
    return tally.result(), limits, plan.title()


# ---------------------------------------------------------------- Qwen Code
def qwen_tokens(days=7):
    """Qwen Code's session logs (~/.qwen/projects/*/chats/*.jsonl) carry a
    usageMetadata block on each model reply."""
    tally = Tally(days)
    for f in glob.glob(os.path.join(HOME, ".qwen/projects/*/chats/*.jsonl")):
        try:
            if os.path.getmtime(f) < tally.since.timestamp():
                continue
            with open(f, "rb") as fh:
                for line in fh:
                    if b"usageMetadata" not in line:
                        continue
                    try:
                        e = json.loads(line)
                        u = e.get("usageMetadata") or {}
                        t = datetime.fromisoformat(e.get("timestamp", "").replace("Z", "+00:00"))
                    except (ValueError, AttributeError):
                        continue
                    total = int(u.get("totalTokenCount") or (u.get("promptTokenCount", 0) + u.get("candidatesTokenCount", 0)))
                    tally.add(t, total, int(u.get("candidatesTokenCount", 0) or 0),
                              e.get("model") or "qwen", e.get("sessionId"))
        except OSError:
            continue
    return tally.result()


def opencode_credential(provider):
    """Return one provider credential from OpenCode's DB without logging it."""
    path = OPENCODE_DB
    try:
        db = sqlite3.connect("file:" + path + "?mode=ro", uri=True, timeout=2)
        row = db.execute("SELECT value FROM credential WHERE integration_id=? AND active=1 LIMIT 1",
                         (provider,)).fetchone()
        db.close()
        return json.loads(row[0]) if row else None
    except (sqlite3.Error, OSError, ValueError, TypeError):
        return None


def openrouter_limits():
    """Fetch OpenRouter's documented key/budget quota using its own API key."""
    auth = opencode_credential("openrouter") or {}
    key = auth.get("key")
    if auth.get("type") != "key" or not key:
        return None, "OpenRouter quota needs an API-key login"
    req = urllib.request.Request("https://openrouter.ai/api/v1/key",
                                 headers={"Authorization": "Bearer " + key,
                                          "Accept": "application/json", "User-Agent": "orrery-agent"})
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.load(response).get("data") or {}
    except Exception as e:
        code = getattr(e, "code", None)
        return None, f"OpenRouter quota unavailable (HTTP {code})" if code else "OpenRouter quota unavailable (offline?)"

    limits = []
    # This is the key-level spend cap. Null means the key has no configured cap.
    cap, remaining = data.get("limit"), data.get("limit_remaining")
    try:
        if cap is not None and remaining is not None and float(cap) > 0:
            pct = round(100 * (float(cap) - float(remaining)) / float(cap))
            limits.append({"name": "OpenRouter key budget", "percent": max(0, min(100, pct)),
                           "resets_at": ""})
    except (ValueError, TypeError):
        pass

    # effective_budget is the budget that will block next (workspace/member/key).
    budget = data.get("effective_budget") or {}
    try:
        budget_cap, spent = float(budget.get("limit_usd")), float(budget.get("spend_usd"))
        budget_is_key_cap = (cap is not None and remaining is not None
                             and abs(budget_cap - float(cap)) < 0.01
                             and abs(spent - (float(cap) - float(remaining))) < 0.01)
        if budget_cap > 0 and not budget_is_key_cap:
            pct = round(100 * spent / budget_cap)
            scope = str(budget.get("scope") or "account").replace("_", " ").title()
            limits.append({"name": "OpenRouter · " + scope, "percent": max(0, min(100, pct)),
                           "resets_at": budget.get("resets_at") or ""})
    except (ValueError, TypeError):
        pass

    free = data.get("free_model_daily_requests") or {}
    try:
        cap, used = int(free.get("limit", 0)), int(free.get("used", 0))
        if cap > 0:
            midnight = (datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
                        + timedelta(days=1)).isoformat()
            limits.append({"name": f"OpenRouter free {used}/{cap}", "percent": max(0, min(100, round(100 * used / cap))),
                           "resets_at": midnight})
    except (ValueError, TypeError):
        pass

    detail = ""
    try:
        if data.get("limit") is not None:
            detail = f"OpenRouter key: ${float(data.get('usage', 0)):.2f} used · ${float(data['limit_remaining']):.2f} remaining"
        elif budget:
            detail = f"OpenRouter budget: ${float(budget.get('spend_usd', 0)):.2f} / ${float(budget.get('limit_usd', 0)):.2f}"
    except (ValueError, TypeError):
        pass
    return {"limits": limits, "detail": detail}, ""


def local_account(id, name, plan, tokens, note="", **extra):
    a = {"id": id, "name": name, "plan": plan, "limits": [], "extra": None, "error": "", "note": note,
         "stats": stats(tokens)}
    a.update(extra)
    return a


# agents `orrery-agent list` offers that have no usage reader yet (keep in sync with its KNOWN list)
OTHER_AGENTS = {"gemini": "Gemini CLI", "copilot": "GitHub Copilot", "crush": "Crush", "grok": "Grok",
                "pi": "Pi", "ori": "Ori", "aider": "Aider", "goose": "Goose"}
EMPTY = {"days": [], "models": [], "messages": 0, "sessions": 0}


def safe(fn, *args):
    """One agent's logs being odd must not take the others down."""
    try:
        return fn(*args)
    except Exception:
        return dict(EMPTY)


def main():
    accounts, tokens = [], {}
    try:
        previous = json.load(open(OUT))
    except (OSError, ValueError):
        previous = {}
    if installed("claude"):
        try:
            a = claude() or {"id": "claude", "name": "Claude Code", "plan": "", "limits": [], "extra": None,
                             "error": "Not signed in: run claude", "url": "https://claude.ai/settings/usage"}
        except Exception as e:
            a = {"id": "claude", "name": "Claude Code", "plan": "", "limits": [], "extra": None, "error": str(e)}
        if a["error"] and not a["limits"]:
            # the usage service said no (rate limit, offline): show the last numbers we had
            old = next((x for x in previous.get("accounts", []) if x.get("id") == "claude"), None)
            if old and old.get("limits"):
                a["limits"], a["plan"] = old["limits"], a["plan"] or old.get("plan", "")
        tokens["claude"] = safe(claude_tokens)
        a["stats"] = stats(tokens["claude"])
        accounts.append(a)

    if installed("opencode"):
        try:
            tok, cost, notice, providers = opencode_tokens()
        except Exception:
            tok, cost, notice, providers = dict(EMPTY), 0, "", []
        quota, quota_err = openrouter_limits() if "openrouter" in providers else (None, "")
        tokens["opencode"] = tok
        accounts.append(local_account(
            "opencode", "OpenCode", "Local usage", tok,
            note=notice or quota_err or "Local token counts; quotas vary by provider.",
            limits=quota["limits"] if quota else [],
            providerDetail=quota["detail"] if quota else "",
            providers=providers, warn=bool(notice),
            url="https://openrouter.ai/settings/credits" if "openrouter" in providers else "https://opencode.ai"))
        accounts[-1]["stats"] = stats(tok, cost)

    if installed("codex"):
        try:
            tok, limits, plan = codex_usage()
        except Exception:
            tok, limits, plan = dict(EMPTY), [], ""
        tokens["codex"] = tok
        accounts.append(local_account("codex", "Codex", plan or "Local usage", tok, limits=limits,
                                      url="https://chatgpt.com/codex/settings/usage",
                                      note="" if tok["models"] else "No usage recorded yet. Run codex once."))
    if installed("qwen"):
        tok = safe(qwen_tokens)
        tokens["qwen"] = tok
        accounts.append(local_account("qwen", "Qwen Code", "Local usage", tok,
                                      note="" if tok["models"] else "No usage recorded yet."))

    # every other agent orrery-agent knows: listed, so the panel agrees with the menu
    for cmd, name in OTHER_AGENTS.items():
        if installed(cmd):
            tokens[cmd] = dict(EMPTY)
            accounts.append(local_account(cmd, name, "", tokens[cmd], note=f"Usage isn't tracked for {name} yet."))

    data = {"updated": int(time.time()), "accounts": accounts,
            "tokens": tokens.get("claude", {"days": [], "models": []}), "tokensByAgent": tokens}
    os.makedirs(STATE, exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh)
    os.replace(tmp, OUT)
    if "--print" in sys.argv:
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
