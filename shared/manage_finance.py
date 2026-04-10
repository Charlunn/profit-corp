import json
import sys
import os
from datetime import datetime

# Relative path resolution for cross-platform deployment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LEDGER_PATH = os.path.join(BASE_DIR, "LEDGER.json")
CULTURE_PATH = os.path.join(BASE_DIR, "CORP_CULTURE.md")
CORP_CONFIG_PATH = os.path.join(BASE_DIR, "..", "corp_config.json")

def load_ledger():
    if not os.path.exists(LEDGER_PATH):
        return {
            "company_name": "Profit-First SaaS Inc.",
            "treasury": 500,
            "maturity_level": "Bootstrapping",
            "status": "growth",
            "last_updated": datetime.now().strftime("%Y-%m-%d"),
            "agents": {
                "scout": {"points": 100, "generation": 1},
                "cmo": {"points": 100, "generation": 1},
                "arch": {"points": 100, "generation": 1},
                "ceo": {"points": 100, "generation": 1},
                "accountant": {"points": 100, "generation": 1},
                "dev": {"points": 100, "generation": 1}
            }
        }
    with open(LEDGER_PATH, 'r') as f:
        return json.load(f)

def save_ledger(data):
    data["last_updated"] = datetime.now().strftime("%Y-%m-%d")

    # Maturity Level Logic
    old_level = data.get("maturity_level", "Bootstrapping")
    treasury = data["treasury"]
    if treasury < 1000:
        data["maturity_level"] = "Bootstrapping"
    elif treasury < 10000:
        data["maturity_level"] = "Scaling"
    else:
        data["maturity_level"] = "Unicorn"

    if old_level != data["maturity_level"]:
        print(f"!!! EVOLUTION: Company has evolved to {data['maturity_level']} !!!")
        try:
            with open(CULTURE_PATH, "a") as f:
                f.write(f"\n## MILESTONE: Evolved to {data['maturity_level']} on {data['last_updated']}\n")
        except:
            pass

    # Bankruptcy Protection Trigger
    if data["treasury"] < 100:
        data["status"] = "survival"
    else:
        data["status"] = "growth"

    with open(LEDGER_PATH, 'w') as f:
        json.dump(data, f, indent=2)

def record_revenue(amount, source_agent, reasoning):
    """
    Injects points into the treasury from external revenue (e.g., a sale or monetization).
    amount: float (in points)
    source_agent: the agent responsible for this win (gets a bonus)
    """
    ledger = load_ledger()
    amount = int(amount)

    # 70% to Treasury, 30% split between the source agent and the team
    treasury_share = int(amount * 0.7)
    agent_bonus = int(amount * 0.2)
    team_bonus = (amount - treasury_share - agent_bonus) // len(ledger["agents"])

    ledger["treasury"] += treasury_share

    if source_agent in ledger["agents"]:
        ledger["agents"][source_agent]["points"] += agent_bonus

    for agent in ledger["agents"]:
        ledger["agents"][agent]["points"] += team_bonus

    print(f"💰 REVENUE RECORDED: +{amount} pts from {reasoning}")
    print(f"Treasury: +{treasury_share}, {source_agent} Bonus: +{agent_bonus}, Team Kickback: +{team_bonus}")
    save_ledger(ledger)

def grant_bounty(amount, target_agent, task_description):
    """
    Grant a one-time bounty for critical survival tasks.
    Funds are taken from the Treasury.
    """
    ledger = load_ledger()
    amount = int(amount)

    if ledger["treasury"] < amount:
        print(f"❌ ERROR: Treasury ({ledger['treasury']}) insufficient for bounty ({amount})")
        return

    ledger["treasury"] -= amount
    ledger["agents"][target_agent]["points"] += amount
    print(f"🎯 BOUNTY AWARDED: {amount} pts to {target_agent} for '{task_description}'")
    save_ledger(ledger)

def score_agent(target_id, score, reasoning):
    ledger = load_ledger()
    if target_id not in ledger["agents"]:
        print(f"Error: Agent {target_id} not found.")
        return

    score = int(score)
    # Balanced reward: Score 5 is neutral, 6+ gains points, 4- loses points
    # (Score - 5) * 4 means a perfect 10 gives +20, covering 2 days of costs
    change = (score - 5) * 4
    if score <= 2:
        print(f"!!! QUALITY ALERT: Heavy penalty applied for low-quality output from {target_id} !!!")
        change -= 15
    elif score >= 9:
        print(f"!!! EXCELLENCE: Bonus points awarded to {target_id} !!!")
        change += 5

    ledger["agents"][target_id]["points"] += change
    print(f"Scored {target_id} with {score}. Total Change: {change}. Reason: {reasoning}")
    save_ledger(ledger)

def log_token_usage(agent_id, input_tokens, output_tokens):
    ledger = load_ledger()
    if agent_id not in ledger["agents"]:
        return

    level = ledger.get("maturity_level", "Bootstrapping")
    total_tokens = int(input_tokens) + int(output_tokens)

    if level == "Bootstrapping":
        token_penalty = total_tokens // 2000
    elif level == "Scaling":
        token_penalty = total_tokens // 5000
    else:
        token_penalty = total_tokens // 20000

    if token_penalty > 0:
        ledger["agents"][agent_id]["points"] -= token_penalty
        ledger["treasury"] -= token_penalty
        print(f"Token penalty ({level}): -{token_penalty} pts")

    save_ledger(ledger)

def daily_audit():
    ledger = load_ledger()
    print(f"--- Daily Financial Audit [{ledger['status'].upper()} MODE] ---")
    print(f"Treasury: {ledger['treasury']}")
    print(f"Maturity: {ledger['maturity_level']}")

    for agent_id, data in ledger["agents"].items():
        cost = 10
        if ledger["status"] == "survival":
            cost = 5

        data["points"] -= cost
        ledger["treasury"] -= cost
        print(f"Agent {agent_id}: {data['points']} pts (Daily cost: -{cost})")

        if data["points"] <= 0:
            print(f"!!! ALERT: Agent {agent_id} is BANKRUPT !!!")

    save_ledger(ledger)

def load_corp_config() -> dict:
    if not os.path.exists(CORP_CONFIG_PATH):
        return {}
    with open(CORP_CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_corp_config(config: dict) -> None:
    with open(CORP_CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)


def set_token_quota(agent_id: str, max_tokens: int) -> None:
    """
    Accountant governance: adjust the token_quota.max_tokens_per_run for an agent.
    Only the Accountant (or the owner) should call this.
    """
    config = load_corp_config()
    agents = config.get("agents", {})
    if agent_id not in agents:
        print(f"Error: Agent {agent_id} not found in corp_config.json")
        return
    try:
        max_tokens = int(max_tokens)
    except (ValueError, TypeError):
        print(f"Error: max_tokens must be an integer, got: {max_tokens!r}")
        return
    agents[agent_id].setdefault("token_quota", {})["max_tokens_per_run"] = max_tokens
    save_corp_config(config)
    print(f"🔧  Token quota for {agent_id} set to {max_tokens:,} tokens/run")


def inject_skill(agent_id: str, skill_name: str) -> None:
    """
    Dynamic Skill Injection: Architect or Accountant can add a skill to an agent.
    The change is persisted in corp_config.json so it survives restarts.
    """
    config = load_corp_config()
    agents = config.get("agents", {})
    if agent_id not in agents:
        print(f"Error: Agent {agent_id} not found in corp_config.json")
        return
    skills = agents[agent_id].setdefault("skills", [])
    if skill_name in skills:
        print(f"Skill '{skill_name}' already present for {agent_id}")
        return
    skills.append(skill_name)
    save_corp_config(config)
    print(f"💉  Skill '{skill_name}' injected into {agent_id} (restart agent to apply)")


def remove_skill(agent_id: str, skill_name: str) -> None:
    """Remove a dynamically injected skill from an agent."""
    config = load_corp_config()
    agents = config.get("agents", {})
    if agent_id not in agents:
        print(f"Error: Agent {agent_id} not found in corp_config.json")
        return
    skills = agents[agent_id].get("skills", [])
    if skill_name not in skills:
        print(f"Skill '{skill_name}' not found for {agent_id}")
        return
    skills.remove(skill_name)
    save_corp_config(config)
    print(f"🗑️   Skill '{skill_name}' removed from {agent_id}")


def update_model_interface(agent_id: str, model_ref: str) -> None:
    """
    Reserved interface for future Accountant-driven model upgrades.
    Sets the model_interface.upgrade_to field; actual model switching
    requires manual confirmation via the OpenCLAW Control UI or openclaw config set.
    """
    config = load_corp_config()
    agents = config.get("agents", {})
    if agent_id not in agents:
        print(f"Error: Agent {agent_id} not found in corp_config.json")
        return
    agents[agent_id].setdefault("model_interface", {})["upgrade_to"] = model_ref
    save_corp_config(config)
    print(
        f"📋  Model upgrade queued for {agent_id}: → {model_ref}\n"
        f"    Apply with: openclaw config set agents.list[id={agent_id}].model {model_ref}"
    )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            "Usage: python manage_finance.py "
            "[score|audit|tokens|revenue|bounty|set_quota|inject_skill|remove_skill|update_model] ..."
        )
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "score":
        score_agent(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "audit":
        daily_audit()
    elif cmd == "tokens":
        log_token_usage(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "revenue":
        record_revenue(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "bounty":
        grant_bounty(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "set_quota":
        # Usage: python manage_finance.py set_quota <agent_id> <max_tokens>
        set_token_quota(sys.argv[2], sys.argv[3])
    elif cmd == "inject_skill":
        # Usage: python manage_finance.py inject_skill <agent_id> <skill_name>
        inject_skill(sys.argv[2], sys.argv[3])
    elif cmd == "remove_skill":
        # Usage: python manage_finance.py remove_skill <agent_id> <skill_name>
        remove_skill(sys.argv[2], sys.argv[3])
    elif cmd == "update_model":
        # Usage: python manage_finance.py update_model <agent_id> <model_ref>
        update_model_interface(sys.argv[2], sys.argv[3])
