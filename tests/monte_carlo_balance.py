#!/usr/bin/env python3
"""
Cent Jours — 蒙特卡洛平衡性测试
用于在 M1/M2 阶段验证核心系统数学模型的平衡性
运行方式: python3 tests/monte_carlo_balance.py [--runs N]
"""

import random
import argparse
import json
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from enum import Enum
import statistics


# ── 数据结构 ──────────────────────────────────────────────────────────────

class BattleResult(Enum):
    DECISIVE_VICTORY = "decisive_victory"
    MARGINAL_VICTORY = "marginal_victory"
    STALEMATE = "stalemate"
    MARGINAL_DEFEAT = "marginal_defeat"
    DECISIVE_DEFEAT = "decisive_defeat"


@dataclass
class ArmyState:
    troops: int
    morale: float       # 0-100
    fatigue: float      # 0-100
    supply: float       # 0-100
    general_skill: float  # 0-100


@dataclass
class GameState:
    day: int = 1
    rouge_noir: float = 0.0
    legitimacy: float = 50.0
    faction_support: Dict[str, float] = field(default_factory=lambda: {
        "liberals": 45.0,
        "nobility": 30.0,
        "populace": 65.0,
        "military": 70.0
    })
    napoleon_army: ArmyState = field(default_factory=lambda: ArmyState(
        troops=6000, morale=85, fatigue=10, supply=70, general_skill=95
    ))
    coalition_strength: float = 100.0  # 反法同盟集结进度 0-200
    outcome: Optional[str] = None


# ── 战斗解算 ──────────────────────────────────────────────────────────────

TERRAIN_MODIFIERS = {
    "plains": 1.0, "hills": 1.15, "mountains": 1.30,
    "forest": 1.20, "urban": 1.25, "ridgeline": 1.35
}

CASUALTIES_TABLE = {
    BattleResult.DECISIVE_VICTORY:  (0.05, 0.35),
    BattleResult.MARGINAL_VICTORY:  (0.15, 0.20),
    BattleResult.STALEMATE:         (0.12, 0.12),
    BattleResult.MARGINAL_DEFEAT:   (0.20, 0.15),
    BattleResult.DECISIVE_DEFEAT:   (0.35, 0.05),
}


def calculate_force_score(army: ArmyState, is_defender: bool,
                           terrain: str = "plains") -> float:
    score = (army.troops
             * (army.morale / 100.0)
             * (1.0 + army.general_skill / 100.0 * 0.5))
    score *= (1.0 - army.fatigue / 100.0 * 0.5)
    if army.supply < 30:
        score *= 0.75
    if is_defender:
        score *= TERRAIN_MODIFIERS.get(terrain, 1.0)
    return score


def resolve_battle(attacker: ArmyState, defender_troops: int,
                   defender_morale: float, terrain: str = "plains") -> BattleResult:
    defender = ArmyState(troops=defender_troops, morale=defender_morale,
                         fatigue=20, supply=80, general_skill=60)
    atk = calculate_force_score(attacker, False)
    dfn = calculate_force_score(defender, True, terrain)
    ratio = (atk / max(dfn, 1.0)) * (1.0 + random.uniform(-0.15, 0.15))

    if ratio > 1.5:   return BattleResult.DECISIVE_VICTORY
    elif ratio > 1.1: return BattleResult.MARGINAL_VICTORY
    elif ratio > 0.9: return BattleResult.STALEMATE
    elif ratio > 0.6: return BattleResult.MARGINAL_DEFEAT
    else:             return BattleResult.DECISIVE_DEFEAT


# ── 命令偏差模型 ──────────────────────────────────────────────────────────

TEMPERAMENT_PROFILES = {
    "cautious":  {"timing": 0.30,  "force_commitment": -0.20},
    "balanced":  {"timing": 0.0,   "force_commitment": 0.0},
    "impulsive": {"timing": -0.20, "force_commitment": 0.30},
    "reckless":  {"timing": -0.30, "force_commitment": 0.50},
}


def calculate_deviation(loyalty: float, temperament: str,
                        distance: int, chaos: float = 0.0) -> Dict:
    base = 1.0 - (loyalty / 100.0) * 0.5
    profile = TEMPERAMENT_PROFILES.get(temperament, TEMPERAMENT_PROFILES["balanced"])
    dist_penalty = min(distance * 0.05, 0.40)
    noise = random.uniform(-chaos * 0.1, chaos * 0.1)

    return {
        "timing": base * profile["timing"] + dist_penalty + noise,
        "force": base * profile["force_commitment"] + noise * 0.5,
        "follows_order": loyalty >= 30 or random.random() > (30 - loyalty) / 30 * 0.4
    }


# ── 政治系统简化模型 ──────────────────────────────────────────────────────

def recalculate_legitimacy(state: GameState) -> None:
    weights = {"liberals": 0.25, "nobility": 0.20, "populace": 0.30, "military": 0.25}
    state.legitimacy = sum(state.faction_support[f] * w for f, w in weights.items())


# ── 一局游戏模拟 ──────────────────────────────────────────────────────────

BATTLE_DAYS = [7, 20, 45, 60, 80, 86, 90, 100]  # 有战斗的日子（简化）
POLICY_POOL = ["conscription", "constitutional", "public_speech",
               "increase_budget", "reduce_taxes"]

# 各势力自然均衡值（无外力时缓慢向此靠拢）
FACTION_EQUILIBRIUM = {
    "liberals": 40.0, "nobility": 35.0,
    "populace": 50.0, "military": 55.0
}
FACTION_RECOVERY_RATE = 0.4   # 每日向均衡值靠拢的速率（绝对值）

# 历史上北上期间拿破仑军队规模变化（Day -> 兵力）
ARMY_SIZE_BY_PHASE = {
    1:  6000,   # 厄尔巴岛部队
    7:  10000,  # 格勒诺布尔驻军加入
    20: 60000,  # 进入巴黎，全军集结
    30: 120000  # 百日王朝军队重建完成
}


def get_army_size_for_day(day: int) -> int:
    """获取对应日期的军队规模下限"""
    size = 6000
    for d, s in sorted(ARMY_SIZE_BY_PHASE.items()):
        if day >= d:
            size = s
    return size


def apply_policy(state: GameState, policy_type: str) -> None:
    policies = {
        "conscription":     {"military": 10, "populace": -8, "liberals": -3, "rn": 5, "eco": -5},
        "constitutional":   {"liberals": 15, "nobility": -5, "populace": 5,  "rn": -8},
        "public_speech":    {"populace": 12, "nobility": -3, "rn": 3},
        "increase_budget":  {"military": 15, "liberals": -5, "rn": 4, "eco": -10},
        "reduce_taxes":     {"populace": 10, "liberals": 3,  "eco": -8},
    }
    if policy_type not in policies:
        return
    p = policies[policy_type]
    for faction in ["liberals", "nobility", "populace", "military"]:
        if faction in p:
            state.faction_support[faction] = max(0, min(100,
                state.faction_support[faction] + p[faction]))
    state.rouge_noir = max(-100, min(100, state.rouge_noir + p.get("rn", 0)))
    recalculate_legitimacy(state)


def apply_faction_recovery(state: GameState) -> None:
    """每日自然恢复：派系支持度缓慢向均衡值靠拢"""
    for faction, eq in FACTION_EQUILIBRIUM.items():
        current = state.faction_support[faction]
        if current < eq:
            state.faction_support[faction] = min(eq, current + FACTION_RECOVERY_RATE)
        elif current > eq:
            state.faction_support[faction] = max(eq, current - FACTION_RECOVERY_RATE * 0.5)
    recalculate_legitimacy(state)


def simulate_one_game(strategy: str = "balanced") -> Dict:
    """模拟一局完整游戏（100天）"""
    state = GameState()
    battles_fought = 0
    victories = 0

    for day in range(1, 101):
        state.day = day

        # 军队规模随历史进程扩张（新兵加入）
        min_troops = get_army_size_for_day(day)
        if state.napoleon_army.troops < min_troops:
            state.napoleon_army.troops = min_troops

        # 策略选择政策（每3天一次，每次1-2个行动）
        if day % 3 == 0:
            if strategy == "military":
                policy = random.choice(["conscription", "increase_budget"])
            elif strategy == "political":
                policy = random.choice(["constitutional", "public_speech", "reduce_taxes"])
            else:  # balanced
                policy = random.choice(POLICY_POOL)
            apply_policy(state, policy)

        # 每日自然恢复
        apply_faction_recovery(state)

        # 反法同盟集结（Day 30后加速）
        if day >= 60:
            state.coalition_strength += 2.0
        elif day >= 30:
            state.coalition_strength += 1.0
        elif day >= 20:
            state.coalition_strength += 0.3

        # 战斗日
        if day in BATTLE_DAYS:
            battles_fought += 1
            # Day 80前的战斗：敌方力量较弱（各个击破阶段）
            if day < 80:
                enemy_troops = int(8000 + state.coalition_strength * 20)
            else:
                # Day 80后：反法同盟主力集结完成
                enemy_troops = int(50000 + state.coalition_strength * 100)

            terrain = random.choice(["plains", "plains", "hills", "ridgeline"])
            result = resolve_battle(state.napoleon_army, enemy_troops, 70.0, terrain)

            casualties_rate = CASUALTIES_TABLE[result]
            state.napoleon_army.troops = max(0, int(
                state.napoleon_army.troops * (1 - casualties_rate[0])
            ))
            morale_delta = {
                BattleResult.DECISIVE_VICTORY: 15,
                BattleResult.MARGINAL_VICTORY: 5,
                BattleResult.STALEMATE: -5,
                BattleResult.MARGINAL_DEFEAT: -15,
                BattleResult.DECISIVE_DEFEAT: -35
            }[result]
            state.napoleon_army.morale = max(0, min(100,
                state.napoleon_army.morale + morale_delta
            ))

            # 军事胜利提升军方和民众支持
            if result in (BattleResult.DECISIVE_VICTORY, BattleResult.MARGINAL_VICTORY):
                victories += 1
                state.faction_support["military"] = min(100,
                    state.faction_support["military"] + 5)
                state.faction_support["populace"] = min(100,
                    state.faction_support["populace"] + 3)
                recalculate_legitimacy(state)
            elif result == BattleResult.DECISIVE_DEFEAT and day >= 86:
                state.outcome = "waterloo_defeat"
                break

        # 检查政治崩溃（连续2个势力跌破10才触发，避免单次政策引发）
        critical_factions = sum(1 for v in state.faction_support.values() if v < 10.0)
        if critical_factions >= 2:
            state.outcome = "political_collapse"
            break

        if state.napoleon_army.troops < 1000:
            state.outcome = "military_annihilation"
            break

    if not state.outcome:
        if victories >= battles_fought * 0.6:
            state.outcome = "napoleon_victory"
        else:
            state.outcome = "waterloo_historical"

    return {
        "days_survived": state.day,
        "outcome": state.outcome,
        "final_legitimacy": state.legitimacy,
        "final_troops": state.napoleon_army.troops,
        "final_morale": state.napoleon_army.morale,
        "battles": battles_fought,
        "victories": victories,
        "coalition_strength": state.coalition_strength,
        "faction_support": dict(state.faction_support),
        "rouge_noir": state.rouge_noir,
    }


# ── 蒙特卡洛主函数 ────────────────────────────────────────────────────────

def run_monte_carlo(n_runs: int = 1000, strategy: str = "balanced") -> Dict:
    results = [simulate_one_game(strategy) for _ in range(n_runs)]

    outcomes = {}
    for r in results:
        outcomes[r["outcome"]] = outcomes.get(r["outcome"], 0) + 1

    legitimacy_vals = [r["final_legitimacy"] for r in results]
    troops_vals = [r["final_troops"] for r in results]
    victory_rates = [r["victories"] / max(r["battles"], 1) for r in results]

    print(f"\n{'='*60}")
    print(f"  Cent Jours 蒙特卡洛平衡测试")
    print(f"  策略: {strategy} | 模拟局数: {n_runs}")
    print(f"{'='*60}")
    print(f"\n  结局分布:")
    for outcome, count in sorted(outcomes.items(), key=lambda x: -x[1]):
        pct = count / n_runs * 100
        bar = "█" * int(pct / 2)
        print(f"    {outcome:35s} {bar:25s} {pct:5.1f}% ({count})")

    print(f"\n  关键指标统计:")
    print(f"    最终合法性  均值={statistics.mean(legitimacy_vals):6.1f}"
          f"  中位={statistics.median(legitimacy_vals):6.1f}"
          f"  标准差={statistics.stdev(legitimacy_vals):5.1f}")
    print(f"    最终兵力    均值={statistics.mean(troops_vals):8.0f}"
          f"  中位={statistics.median(troops_vals):8.0f}")
    print(f"    战斗胜率    均值={statistics.mean(victory_rates)*100:5.1f}%")

    # 平衡性评估
    print(f"\n  平衡性评估:")
    victory_pct = (outcomes.get("napoleon_victory", 0) / n_runs) * 100
    collapse_pct = (outcomes.get("political_collapse", 0) / n_runs) * 100

    if 15 <= victory_pct <= 35:
        print(f"  ✅ 胜率 {victory_pct:.1f}% — 在目标范围(15%-35%)内，游戏有挑战性但可胜")
    elif victory_pct < 15:
        print(f"  ⚠️  胜率 {victory_pct:.1f}% — 过低，考虑降低敌方集结速度或提升初始兵力")
    else:
        print(f"  ⚠️  胜率 {victory_pct:.1f}% — 过高，考虑加快敌方集结或提高将领偏差")

    if collapse_pct > 40:
        print(f"  ⚠️  政治崩溃率 {collapse_pct:.1f}% — 过高，政治系统压力过大")
    else:
        print(f"  ✅ 政治崩溃率 {collapse_pct:.1f}% — 在可接受范围内")

    print(f"\n{'='*60}\n")

    return {
        "n_runs": n_runs,
        "strategy": strategy,
        "outcomes": outcomes,
        "victory_rate": victory_pct,
        "political_collapse_rate": collapse_pct,
        "avg_legitimacy": statistics.mean(legitimacy_vals),
        "avg_troops": statistics.mean(troops_vals),
    }


def run_all_strategies(n_runs: int = 1000) -> None:
    """对比三种策略的结果"""
    print("\n  ▶ 运行三种策略对比测试...")
    all_results = {}
    for strategy in ["military", "political", "balanced"]:
        all_results[strategy] = run_monte_carlo(n_runs, strategy)

    print(f"\n{'='*60}")
    print("  策略对比汇总")
    print(f"{'='*60}")
    print(f"  {'策略':12s} {'胜率':>8s} {'政治崩溃':>10s} {'均值合法性':>12s}")
    print(f"  {'-'*48}")
    for s, r in all_results.items():
        print(f"  {s:12s} {r['victory_rate']:7.1f}% "
              f"{r['political_collapse_rate']:9.1f}% "
              f"{r['avg_legitimacy']:11.1f}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cent Jours 蒙特卡洛平衡测试")
    parser.add_argument("--runs", type=int, default=1000, help="模拟局数（默认1000）")
    parser.add_argument("--strategy", type=str, default="all",
                        choices=["military", "political", "balanced", "all"],
                        help="测试策略（默认all=三种均测）")
    args = parser.parse_args()

    if args.strategy == "all":
        run_all_strategies(args.runs)
    else:
        run_monte_carlo(args.runs, args.strategy)
