import datetime as dt
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("todoist_bridge", Path(__file__).with_name("todoist.py"))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class TodoistBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.original = (bridge.CACHE, bridge.NOTIFIED, bridge.AUTH_MARK, bridge.AUTH_ERR)
        bridge.CACHE = self.root / "snapshot.json"
        bridge.NOTIFIED = self.root / "notified.json"
        bridge.AUTH_MARK = self.root / "authorizing.json"
        bridge.AUTH_ERR = self.root / "auth-error.json"

    def tearDown(self):
        bridge.CACHE, bridge.NOTIFIED, bridge.AUTH_MARK, bridge.AUTH_ERR = self.original
        self.temp.cleanup()

    def test_private_cache_permissions(self):
        target = self.root / "nested" / "snapshot.json"
        bridge.write_private(target, {"hello": "world"})
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertEqual(target.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(bridge.read_json(target), {"hello": "world"})

    def test_pagination_fetches_all_pages(self):
        seen = []
        def mock_request(url, **kwargs):
            seen.append(url)
            return {"results": [{"id": len(seen)}], "next_cursor": "NEXT" if len(seen) == 1 else None}
        with patch.object(bridge, "request", side_effect=mock_request):
            self.assertEqual(len(bridge.all_pages("/tasks", "ACCESS")), 2)
        self.assertIn("cursor=NEXT", seen[1])

    def test_due_information_for_day_and_clock(self):
        now = dt.datetime(2026, 10, 21, 13, 0, tzinfo=dt.timezone.utc).astimezone()
        day = bridge.due_info({"due": {"date": "2026-10-20"}}, now)
        self.assertTrue(day["overdue"])
        self.assertFalse(day["today"])
        self.assertEqual(day["dueDatetime"], "")
        with_time = bridge.due_info({"due": {"datetime": "2026-10-21T18:00:00Z"}}, now)
        self.assertFalse(with_time["overdue"])
        self.assertTrue(with_time["today"])

    def test_normalization_priorities_and_inbox(self):
        tasks = [
            {"id": "a", "project_id": "p", "content": "Later", "priority": 4, "due": None},
            {"id": "b", "project_id": "i", "content": "Now", "priority": 1, "due": {"date": dt.date.today().isoformat()}},
            {"id": "c", "project_id": "p", "content": "Done", "checked": True},
        ]
        projects = [{"id": "i", "name": "Inbox", "is_inbox_project": True},
                    {"id": "p", "name": "Work"}]
        result = bridge.normalize(tasks, projects)
        self.assertEqual([task["id"] for task in result], ["b", "a"])
        self.assertTrue(result[0]["today"])
        self.assertTrue(result[0]["inbox"])
        self.assertEqual(result[0]["priority"], 1)

    def test_mutations_use_correct_v1_paths(self):
        invocations = []
        def fake_request(url, method="GET", body=None, **kwargs):
            invocations.append((url, method, body, kwargs))
            return {"id": "task1"}
        with patch.object(bridge, "secret_read", return_value={"access_token": "token", "expires_at": 0}), \
             patch.object(bridge, "request", side_effect=fake_request):
            bridge.mutate("quick", {"text": "Buy milk tomorrow"})
            bridge.mutate("create", {"content": "Task", "priority": 3})
            bridge.mutate("update", {"id": "abc", "content": "Renamed"})
            bridge.mutate("move", {"id": "abc", "project_id": "p"})
            bridge.mutate("close", {"id": "abc"})
            bridge.mutate("reopen", {"id": "abc"})
        self.assertEqual([call[0].replace(bridge.API, "") for call in invocations], [
            "/tasks/quick", "/tasks", "/tasks/abc", "/tasks/abc/move",
            "/tasks/abc/close", "/tasks/abc/reopen",
        ])
        self.assertEqual(invocations[0][2], {"text": "Buy milk tomorrow"})
        self.assertTrue(all(call[3].get("request_id") for call in invocations))

    def test_notifications_deduplicated(self):
        due = (dt.datetime.now().astimezone() + dt.timedelta(minutes=20)).isoformat()
        tasks = [{"id": "a", "content": "Meeting", "dueDate": due[:10], "dueDatetime": due, "overdue": False}]
        with patch.object(bridge.shutil, "which", return_value="/usr/bin/notify-send"), \
             patch.object(bridge.subprocess, "Popen") as popen:
            bridge.maybe_notify(tasks, {"reminderMinutes": 30, "notifyDue": True})
            bridge.maybe_notify(tasks, {"reminderMinutes": 30, "notifyDue": True})
        self.assertEqual(popen.call_count, 1)

    def test_cached_snapshot_when_offline(self):
        bridge.write_private(bridge.CACHE, {"tasks": [{"id": "cached"}], "projects": []})
        with patch.object(bridge, "secret_read", return_value={"access_token": "token", "expires_at": 0}), \
             patch.object(bridge, "all_pages", side_effect=bridge.TodoistError("Offline")):
            result = bridge.status({})
        self.assertTrue(result["stale"])
        self.assertEqual(result["tasks"][0]["id"], "cached")

    def test_missing_connection_no_secret_or_login(self):
        with patch.object(bridge, "secret_read", return_value=None), \
             patch.object(bridge.shutil, "which", return_value="/usr/bin/secret-tool"):
            result = bridge.status({})
        self.assertFalse(result["connected"])
        self.assertEqual(result["tasks"], [])

    def test_invalid_task_rejected(self):
        with patch.object(bridge, "secret_read", return_value={"access_token": "token", "expires_at": 0}):
            with self.assertRaises(bridge.TodoistError):
                bridge.mutate("close", {"id": "../bad"})


if __name__ == "__main__":
    unittest.main()
