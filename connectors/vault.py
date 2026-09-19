"""Encrypted credential storage interface (Phase 1: Fernet-at-rest in SQLite).

Swap :class:`FernetVault` for a Secrets Manager / HashiCorp Vault implementation
of :class:`CredentialVault` when moving to production multi-tenant.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass

from cryptography.fernet import Fernet, InvalidToken

from data.store import Store


@dataclass(frozen=True)
class Credential:
    connector_name: str
    value: str
    refresh_token: str | None = None
    expires_at: str | None = None


class CredentialVault(ABC):
    @abstractmethod
    def put(self, tenant_id: str, connector_name: str, value: str,
            refresh_token: str | None = None, expires_at: str | None = None) -> None: ...

    @abstractmethod
    def get(self, tenant_id: str, connector_name: str) -> Credential | None: ...

    @abstractmethod
    def delete(self, tenant_id: str, connector_name: str) -> None: ...

    @abstractmethod
    def list_names(self, tenant_id: str) -> list[str]: ...

    def is_configured(self, tenant_id: str, connector_name: str) -> bool:
        return self.get(tenant_id, connector_name) is not None


class FernetVault(CredentialVault):
    def __init__(self, store: Store, encryption_key: str) -> None:
        if not encryption_key:
            raise ValueError("VAULT_ENCRYPTION_KEY is required for the credential vault")
        self._store = store
        self._fernet = Fernet(encryption_key.encode() if isinstance(encryption_key, str) else encryption_key)

    def put(self, tenant_id: str, connector_name: str, value: str,
            refresh_token: str | None = None, expires_at: str | None = None) -> None:
        enc = self._fernet.encrypt(value.encode("utf-8"))
        rt = self._fernet.encrypt(refresh_token.encode("utf-8")) if refresh_token else None
        self._store.put_credential(tenant_id, connector_name, enc, rt, expires_at)

    def get(self, tenant_id: str, connector_name: str) -> Credential | None:
        row = self._store.get_credential(tenant_id, connector_name)
        if row is None:
            return None
        try:
            value = self._fernet.decrypt(row.encrypted_value).decode("utf-8")
            rt = self._fernet.decrypt(row.oauth_refresh_token).decode("utf-8") if row.oauth_refresh_token else None
        except InvalidToken as exc:
            raise RuntimeError("credential cannot be decrypted with the configured VAULT_ENCRYPTION_KEY") from exc
        return Credential(connector_name, value, rt, row.expires_at)

    def delete(self, tenant_id: str, connector_name: str) -> None:
        self._store.delete_credential(tenant_id, connector_name)

    def list_names(self, tenant_id: str) -> list[str]:
        return self._store.list_credential_names(tenant_id)


class InMemoryVault(CredentialVault):
    """For tests and local development without an encryption key."""

    def __init__(self) -> None:
        self._data: dict[tuple[str, str], Credential] = {}

    def put(self, tenant_id, connector_name, value, refresh_token=None, expires_at=None) -> None:
        self._data[(tenant_id, connector_name)] = Credential(connector_name, value, refresh_token, expires_at)

    def get(self, tenant_id, connector_name):
        return self._data.get((tenant_id, connector_name))

    def delete(self, tenant_id, connector_name) -> None:
        self._data.pop((tenant_id, connector_name), None)

    def list_names(self, tenant_id):
        return sorted(n for (t, n) in self._data if t == tenant_id)
