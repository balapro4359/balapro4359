"""Orchestration layer: engine-agnostic interface, router, approval gate, orchestrator.

Rule: nothing outside ``orchestration/engines/`` imports an agent framework
(Claude Agent SDK today, LangGraph tomorrow). Everything else talks to
``orchestration.interface``.
"""
