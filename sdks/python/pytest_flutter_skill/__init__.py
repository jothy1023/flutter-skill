"""pytest-flutter-skill — pytest fixture for flutter-skill MCP automation."""

from .client import FlutterSkillClient
from .fixture import flutter_skill

__all__ = ["FlutterSkillClient", "flutter_skill"]
__version__ = "0.1.0"
