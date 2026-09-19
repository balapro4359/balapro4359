"""chat_id -> tenant_id + active brand, backed by the Session model. Includes onboarding."""
from __future__ import annotations

from dataclasses import dataclass

from data.models import Brand, Session, Tenant
from data.store import Store

CHANNEL = "telegram"


@dataclass(frozen=True)
class Resolved:
    session: Session
    tenant: Tenant
    brand: Brand | None


class SessionMap:
    def __init__(self, store: Store) -> None:
        self.store = store

    def resolve(self, chat_id: str) -> Resolved | None:
        s = self.store.get_session_by_ref(CHANNEL, str(chat_id))
        if s is None:
            return None
        tenant = self.store.get_tenant(s.tenant_id)
        if tenant is None:
            return None
        brand = self.store.get_brand(s.tenant_id, s.active_brand_id) if s.active_brand_id else None
        return Resolved(s, tenant, brand)

    def create_tenant_for_chat(self, chat_id: str, workspace_name: str, brand_name: str | None = None) -> Resolved:
        if self.store.get_session_by_ref(CHANNEL, str(chat_id)) is not None:
            raise ValueError("this chat is already linked to a workspace")
        tenant = self.store.create_tenant(workspace_name)
        brand = self.store.create_brand(tenant.id, brand_name or workspace_name)
        session = self.store.create_session(tenant.id, CHANNEL, str(chat_id), brand.id)
        return Resolved(session, tenant, brand)

    def link_chat_with_code(self, chat_id: str, code: str) -> Resolved | None:
        if self.store.get_session_by_ref(CHANNEL, str(chat_id)) is not None:
            raise ValueError("this chat is already linked to a workspace")
        tenant_id = self.store.redeem_onboarding_code(code)
        if tenant_id is None:
            return None
        brands = self.store.list_brands(tenant_id)
        session = self.store.create_session(tenant_id, CHANNEL, str(chat_id), brands[0].id if brands else None)
        return self.resolve(chat_id)

    def switch_brand(self, chat_id: str, brand_name: str) -> Brand | None:
        r = self.resolve(chat_id)
        if r is None:
            return None
        brand = self.store.find_brand_by_name(r.tenant.id, brand_name)
        if brand is None:
            return None
        self.store.set_active_brand(r.session.id, brand.id)
        return brand

    def create_brand(self, chat_id: str, brand_name: str) -> Brand | None:
        r = self.resolve(chat_id)
        if r is None:
            return None
        brand = self.store.create_brand(r.tenant.id, brand_name)
        self.store.set_active_brand(r.session.id, brand.id)
        return brand
