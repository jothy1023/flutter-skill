"""pytest fixture definition for flutter-skill."""

from __future__ import annotations

import pytest

from .client import FlutterSkillClient


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("flutter-skill")
    group.addoption(
        "--flutter-skill-executable",
        default="flutter_skill",
        help="Path to the flutter_skill executable (default: flutter_skill)",
    )
    group.addoption(
        "--flutter-skill-timeout",
        type=int,
        default=30,
        help="Seconds to wait for each tool call response (default: 30)",
    )


@pytest.fixture
def flutter_skill(request: pytest.FixtureRequest) -> "FlutterSkillClient":
    """Session-scoped fixture that provides a connected FlutterSkillClient.

    The MCP server is started before the test and stopped after.
    Connection to the app must be established inside the test via
    ``flutter_skill.connect_app()`` or ``flutter_skill.connect_cdp()``.

    Example::

        def test_login(flutter_skill):
            flutter_skill.connect_app()
            flutter_skill.tap(text="Login")
            flutter_skill.assert_visible(text="Dashboard")
    """
    executable = request.config.getoption("--flutter-skill-executable")
    timeout = request.config.getoption("--flutter-skill-timeout")

    client = FlutterSkillClient(executable=executable, timeout=timeout)
    client.start()
    yield client
    client.stop()
