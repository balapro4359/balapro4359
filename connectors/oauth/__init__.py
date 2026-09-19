"""OAuth connectors: interface for storing access/refresh tokens per tenant.

Phase 1 stores tokens only. Running the authorization-code flow (redirect URL,
state, PKCE) is Phase 2 work and must never be triggered from a chat message.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from connectors.vault import CredentialVault


@dataclass(frozen=True)
class OAuthTokens:
    access_token: str
    refresh_token: str | None
    expires_at: str | None  # ISO-8601 UTC


def store_tokens(vault: CredentialVault, tenant_id: str, connector_name: str, tokens: OAuthTokens) -> None:
    vault.put(tenant_id, connector_name, tokens.access_token, tokens.refresh_token, tokens.expires_at)


def is_expired(vault: CredentialVault, tenant_id: str, connector_name: str) -> bool:
    cred = vault.get(tenant_id, connector_name)
    if cred is None or not cred.expires_at:
        return cred is None
    return datetime.fromisoformat(cred.expires_at) <= datetime.now(timezone.utc)
