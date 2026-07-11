"""Shared validation and normalization for root ``models`` configuration."""

MODEL_TIERS = {"fast", "standard", "deep"}
MODEL_PROVIDERS = {"anthropic", "openai", "google", "openrouter"}
EFFORT_LEVELS = {"minimal", "low", "medium", "high", "xhigh"}


def normalize_models(models, fail):
    """Validate root models and return canonical scalar or ordered array leaves."""
    if not isinstance(models, dict):
        fail("`models` must be an object with fast/standard/deep keys and/or provider objects")

    valid_model_keys = MODEL_TIERS | MODEL_PROVIDERS
    bad = sorted(set(models.keys()) - valid_model_keys)
    if bad:
        fail("unknown models key(s): {} (valid tiers: {}; valid providers: {})".format(
            ", ".join(bad),
            ", ".join(sorted(MODEL_TIERS)),
            ", ".join(sorted(MODEL_PROVIDERS)),
        ))

    cleaned_models = {}
    for key, value in models.items():
        if key in MODEL_TIERS:
            cleaned_models[key] = _parse_model_leaf("models.{}".format(key), value, fail)
            continue

        if not isinstance(value, dict):
            fail("models.{} must be an object with fast/standard/deep keys".format(key))
        bad_tiers = sorted(set(value.keys()) - MODEL_TIERS)
        if bad_tiers:
            fail("unknown models.{} tier(s): {} (valid: {})".format(
                key,
                ", ".join(bad_tiers),
                ", ".join(sorted(MODEL_TIERS)),
            ))
        cleaned_models[key] = {
            tier: _parse_model_leaf("models.{}.{}".format(key, tier), leaf, fail)
            for tier, leaf in value.items()
        }

    return cleaned_models


def _parse_model_leaf(label, value, fail):
    if isinstance(value, list):
        if not value:
            fail("{} must be a non-empty array".format(label))
        return [
            _parse_scalar_model_leaf("{}[{}]".format(label, index), entry, fail)
            for index, entry in enumerate(value)
        ]

    return _parse_scalar_model_leaf(label, value, fail)


def _parse_scalar_model_leaf(label, value, fail):
    if isinstance(value, str):
        if not value.strip():
            fail("{} must be a non-empty string".format(label))
        return {"model": value.strip()}

    if isinstance(value, dict):
        bad_leaf = sorted(set(value.keys()) - {"model", "effort"})
        if bad_leaf:
            fail("{} has unknown key(s): {} (valid: model, effort)".format(
                label, ", ".join(bad_leaf)))
        model = value.get("model")
        if not isinstance(model, str) or not model.strip():
            fail("{}.model must be a non-empty string".format(label))
        leaf = {"model": model.strip()}
        if "effort" in value:
            effort = value["effort"]
            if not isinstance(effort, str):
                fail("{}.effort must be a string".format(label))
            normalized_effort = effort.strip().lower()
            if normalized_effort:
                if normalized_effort not in EFFORT_LEVELS:
                    fail("{}.effort must be one of: {} (got '{}')".format(
                        label, ", ".join(sorted(EFFORT_LEVELS)), effort))
                leaf["effort"] = normalized_effort
        return leaf

    fail("{} must be a string or an object with a `model` key".format(label))
