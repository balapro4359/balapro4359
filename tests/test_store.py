from data.models import AuditLogEntry, UsageRecord


def test_tenant_brand_session_scoping(store):
    t1 = store.create_tenant("A")
    t2 = store.create_tenant("B")
    b1 = store.create_brand(t1.id, "Brand A")
    assert store.get_brand(t1.id, b1.id) is not None
    assert store.get_brand(t2.id, b1.id) is None, "brands must not leak across tenants"
    assert store.find_brand_by_name(t2.id, "Brand A") is None
    s = store.create_session(t2.id, "telegram", "999", None)
    try:
        store.set_active_brand(s.id, b1.id)
    except PermissionError:
        pass
    else:
        raise AssertionError("session must not activate another tenant's brand")


def test_conversation_is_tenant_and_session_scoped(store, tenant_session):
    t, b, s = tenant_session
    other = store.create_tenant("Other")
    store.append_message(t.id, s.id, "user", "hello")
    store.append_message(t.id, s.id, "assistant", "hi")
    assert store.recent_messages(t.id, s.id) == [("user", "hello"), ("assistant", "hi")]
    assert store.recent_messages(other.id, s.id) == []


def test_audit_log_is_append_only(store, tenant_session):
    t, _, _ = tenant_session
    e = store.append_audit(AuditLogEntry(tenant_id=t.id, actor="system", action="x", tool_call={"a": 1}))
    assert e.id is not None
    assert not any(name.startswith(("update_audit", "delete_audit")) for name in dir(store))
    assert store.list_audit(t.id)[0].action == "x"
    assert store.list_audit("someone-else") == []


def test_usage_and_approvals(store, tenant_session):
    t, b, s = tenant_session
    store.record_usage(UsageRecord(t.id, b.id, s.id, "fake", "claude-sonnet-5", ["seo-audit"], 100, 50, 0, 0, 0.0007))
    assert store.usage_summary(t.id)["runs"] == 1
    a = store.create_approval(t.id, "send_email_campaign", "send it", "$2.10")
    assert store.list_approvals(t.id, "pending")[0].id == a.id
    store.decide_approval(a.id, "approved", "telegram:1:user")
    assert store.get_approval(a.id).status == "approved"
    # a decision is final
    store.decide_approval(a.id, "rejected", "someone")
    assert store.get_approval(a.id).status == "approved"


def test_onboarding_codes(store):
    t = store.create_tenant("A")
    code = store.create_onboarding_code(t.id)
    assert store.redeem_onboarding_code(code.lower()) == t.id
    assert store.redeem_onboarding_code(code) is None, "codes are single-use"
    assert store.redeem_onboarding_code("NOPE") is None


def test_migrations_are_idempotent(tmp_path):
    from data.store import Store
    p = str(tmp_path / "db.sqlite")
    Store(p).close()
    s2 = Store(p)
    assert s2.list_tenants() == []
    s2.close()
