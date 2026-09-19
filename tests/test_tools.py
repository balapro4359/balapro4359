import asyncio
import json

import pytest

from connectors.vault import InMemoryVault
from tools.registry import ToolContext, default_registry

CH = [{"name": "Google Ads", "spend": 5000, "conversions": 150, "revenue": 22500},
      {"name": "Meta", "spend": 3000, "conversions": 40, "revenue": 2400}]


@pytest.fixture
def reg():
    return default_registry()


def run(reg, name, args, ctx=None):
    return json.loads(asyncio.run(reg.get(name).invoke(ctx or ToolContext("t", "b"), args)))


def test_specs_are_plain_json_schema(reg):
    for spec in reg.specs():
        assert spec.json_schema["type"] == "object"
        assert "properties" in spec.json_schema
        json.dumps(spec.json_schema)  # serialisable


def test_write_tools_require_approval(reg):
    gated = {n for n in reg.names() if reg.get(n).spec.requires_approval}
    assert gated == {"send_email_campaign", "crm_sync_contacts", "launch_ad_campaign", "schedule_social_post"}
    for n in gated:
        t = reg.get(n)
        assert t.summarize and t.estimate_cost


def test_roi_calculate(reg):
    out = run(reg, "roi_calculate", {"channels": CH, "attribution": "linear", "ltv": 1200})
    assert out["summary"]["best_channel"] == "Google Ads"
    assert out["channels"][0]["roas"] == 4.5
    assert abs(sum(c["attribution_weight"] for c in out["channels"]) - 1) < 1e-6


def test_roi_rejects_negative(reg):
    with pytest.raises(ValueError):
        run(reg, "roi_calculate", {"channels": [{"name": "x", "spend": -1, "conversions": 0, "revenue": 0}]})


def test_budget_optimize_and_clv(reg):
    out = run(reg, "budget_optimize", {"channels": CH, "total_budget": 10000})
    assert out["optimized_allocation"]["total_spend"] == 10000
    clv = run(reg, "clv_calculate", {"model": "contractual", "monthly_revenue": 99, "churn_rate": 0.05, "margin": 70, "cac": 500})
    assert clv["clv"] > 0 and "cac_analysis" in clv


def test_ab_tools(reg):
    ss = run(reg, "ab_sample_size", {"baseline_rate": 0.05, "mde": 0.10, "mde_type": "relative", "daily_traffic": 5000})
    assert ss["target_rate"] == 0.055 and ss["sample_per_variant"] > 1000 and ss["estimated_days"]
    sig = run(reg, "ab_significance", {"control_visitors": 10000, "control_conversions": 300,
                                       "variant_visitors": 10000, "variant_conversions": 350})
    assert sig["significant"] is True


def test_text_scorers(reg):
    assert run(reg, "headline_score", {"headlines": ["10 Proven Ways to Cut Churn"]})["results"][0]["power_word_count"] >= 1
    subj = run(reg, "email_subject_score", {"subjects": ["50% Off Today Only!!!"]})["results"][0]
    assert "score" in subj or "overall_score" in subj
    spam = run(reg, "email_spam_check", {"content": "Buy now! 100% free offer!!! Click here", "subject": "URGENT"})
    assert spam["risk_score"] > 0


def test_utm_and_clusters(reg):
    utm = run(reg, "utm_build", {"links": [{"base_url": "https://acme.com/x", "source": "facebook",
                                           "medium": "paid_social", "campaign": "q4"}]})["results"][0]
    assert "utm_campaign=q4" in utm["tagged_url"] and utm["ga4_channel_grouping"] == "Paid Social"
    kc = run(reg, "keyword_cluster", {"keywords": [{"keyword": "crm software", "volume": 5000},
                                                  {"keyword": "best crm software", "volume": 3000},
                                                  {"keyword": "email marketing tools", "volume": 4000}]})
    assert kc["clusters"]


def test_connector_tools_are_mock_and_tenant_scoped(reg):
    vault = InMemoryVault()
    vault.put("t1", "klaviyo", "secret-key-123")
    ctx = ToolContext("t1", "b1", vault=vault)
    out = run(reg, "send_email_campaign", {"connector": "klaviyo", "campaign_name": "Q4", "segment": "all",
                                           "recipient_count": 4200, "subject": "Hi", "body_html": "<p>x</p>"}, ctx)
    assert out["status"] == "mock_executed" and out["credential_status"] == "configured"
    other = run(reg, "list_connectors", {}, ToolContext("t2", None, vault=vault))
    assert other["configured"] == []
    assert reg.get("send_email_campaign").estimate_cost({"recipient_count": 4200}) == "$2.10"
