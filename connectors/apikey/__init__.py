"""API-key connectors: the credential is a static token stored in the vault."""
from __future__ import annotations

from connectors.vault import CredentialVault


def store_api_key(vault: CredentialVault, tenant_id: str, connector_name: str, api_key: str) -> None:
    if not api_key or len(api_key) < 8:
        raise ValueError("API key looks invalid")
    vault.put(tenant_id, connector_name, api_key)


def auth_headers(vault: CredentialVault, tenant_id: str, connector_name: str) -> dict[str, str]:
    cred = vault.get(tenant_id, connector_name)
    if cred is None:
        raise PermissionError(f"connector {connector_name!r} is not configured for tenant {tenant_id}")
    return {"Authorization": f"Bearer {cred.value}"}
