import json
import sys
import os
from datetime import datetime

# Relative path resolution for cross-platform deployment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LEDGER_PATH = os.path.join(BASE_DIR, "LEDGER.json")
AUDIT_LOG_PATH = os.path.join(BASE_DIR, "AUDIT_LOG.csv")
CULTURE_PATH = os.path.join(BASE_DIR, "CORP_CULTURE.md")

def log_event(event_type, agent_id, amount, reasoning):
    """Logs financial events to a persistent CSV for long-term analysis."""
    file_exists = os.path.exists(AUDIT_LOG_PATH)
    try:
        with open(AUDIT_LOG_PATH, 'a') as f:
            if not file_exists:
                f.write("timestamp,event_type,agent_id,amount,reasoning\n")
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            # Basic CSV escaping: replace quotes with double quotes and wrap in quotes
            clean_reason = f'"{reasoning.replace(\'"\', \'""\')}"'
            f.write(f"{timestamp},{event_type},{agent_id},{amount},{clean_reason}\n")
    except Exception as e:
        print(f"Warning: Could not write to audit log: {e}")

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
    log_event("revenue", source_agent, amount, reasoning)

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
    log_event("bounty", target_agent, -amount, task_description)

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
    log_event("score", target_id, change, f"Score: {score}, Reason: {reasoning}")

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
        log_event("token_penalty", agent_id, -token_penalty, f"Tokens: {total_tokens} ({level})")

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
        log_event("daily_cost", agent_id, -cost, "Daily audit operational cost")

        if data["points"] <= 0:
            print(f"!!! ALERT: Agent {agent_id} is BANKRUPT !!!")

    save_ledger(ledger)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python manage_finance.py [score|audit|tokens] ...")
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
