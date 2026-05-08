#!/usr/bin/env python3
"""Generate CookieFarm config.yml from our unified YAML config files."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import yaml

CONFIG_DIR = Path(os.environ.get("AD_INFRA_CONFIG_DIR", "/config"))
OUTPUT = Path(os.environ.get("COOKIEFARM_CONFIG_OUT", "/app/config.yml"))


def _load(name: str) -> dict:
    p = CONFIG_DIR / f"{name}.yml"
    if not p.exists():
        return {}
    return yaml.safe_load(p.read_text()) or {}


def generate() -> None:
    game = _load("game")
    farm = _load("farm")
    services = _load("services")

    # Build services map: {name: port}
    services_map: dict[str, int] = {}
    for svc in services.get("services", []):
        name = svc.get("name", "")
        ports = svc.get("ports", [])
        for port in ports:
            services_map[f"{name}-{port}"] = port

    config = {
        "configured": True,
        "server": {
            "url_flag_checker": game.get("gameserver_url", "http://10.10.0.1:8080/flags"),
            "team_token": game.get("team_token", ""),
            "submit_flag_checker_time": farm.get("submit_flag_checker_time", 30),
            "max_flag_batch_size": farm.get("max_flag_batch_size", 1000),
            "protocol": "cc_http",
            "tick_time": game.get("tick_duration_sec", 120),
            "flag_ttl": game.get("flag_lifetime_ticks", 5),
            "start_time": game.get("start", ""),
            "end_time": game.get("end", ""),
        },
        "shared": {
            "services": services_map,
            "regex_flag": game.get("flag_regex", "[A-Z0-9]{31}="),
            "format_ip_teams": game.get("ip_format", "10.60.{}.1"),
            "my_team_id": game.get("team_id", 0),
            "url_flag_ids": game.get("flag_ids_url", "http://10.10.0.1:8081/flagIds"),
            "nop_team": game.get("nop_team", 0),
            "range_ip_teams": game.get("range_ip_teams", 30),
            "flagids_format": "[service].[team].[id]",
        },
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(yaml.dump(config, default_flow_style=False, sort_keys=False))
    print(f"Generated {OUTPUT}", flush=True)


if __name__ == "__main__":
    generate()
