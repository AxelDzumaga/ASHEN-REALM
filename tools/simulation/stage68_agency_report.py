#!/usr/bin/env python3
from __future__ import annotations
import argparse, json
from collections import Counter
from pathlib import Path
from statistics import mean

def load(path):
    return [json.loads(x) for x in Path(path).read_text(encoding="utf-8").splitlines() if x.strip()]

def avg(rows, key): return round(mean(float(r.get(key, 0)) for r in rows), 3) if rows else 0
def merge(rows, key):
    c=Counter()
    for r in rows: c.update(r.get(key, {}))
    return dict(c)
def stacks(row,key): return sum(int(v) for v in row.get(key,{}).values())

def summary(rows):
    bosses=[r for r in rows if r.get("boss_outcome")!="not_reached"]
    event_choices=merge(rows,"event_choices"); treasure_choices=merge(rows,"treasure_choices")
    return {
      "runs":len(rows), "win_rate":round(100*sum(r["outcome"]=="victory" for r in rows)/max(1,len(rows)),2),
      "boss_reach":round(100*len(bosses)/max(1,len(rows)),2),
      "boss_win":round(100*sum(r.get("boss_outcome")=="victory" for r in bosses)/max(1,len(bosses)),2),
      "hp_at_boss":avg(bosses,"boss_entry_hp"), "final_hp":avg(rows,"final_hp"), "ash":avg(rows,"ash"), "xp":avg(rows,"xp"),
      "events_per_run":avg(rows,"events"), "event_hp_cost":avg(rows,"event_hp_cost"), "event_flags":avg(rows,"event_flags_set"),
      "chain_completion_rate":round(100*sum(r.get("event_chain_completions",0)>0 for r in rows)/max(1,len(rows)),2),
      "treasures_per_run":avg(rows,"treasures"), "boon_stacks":round(mean(stacks(r,"boons") for r in rows),3),
      "augment_stacks":round(mean(stacks(r,"augments") for r in rows),3),
      "event_choices":event_choices, "event_rewards":merge(rows,"event_rewards_received"),
      "treasure_choices":treasure_choices, "treasure_reward_types":merge(rows,"treasure_reward_types"),
      "route_chosen_types":merge(rows,"route_chosen_tile_types"),
      "event_meaningful_rate":round(100*sum(r.get("event_meaningful_choices",0) for r in rows)/max(1,sum(r.get("events",0) for r in rows)),2),
      "treasure_meaningful_rate":round(100*sum(r.get("treasure_meaningful_choices",0) for r in rows)/max(1,sum(r.get("treasures",0) for r in rows)),2),
    }

def main():
    p=argparse.ArgumentParser();p.add_argument("--old",required=True);p.add_argument("--agency",required=True);p.add_argument("--output",required=True);a=p.parse_args()
    old,new=load(a.old),load(a.agency); om={(r['biome'],r['policy'],r['seed']):r for r in old}; nm={(r['biome'],r['policy'],r['seed']):r for r in new}
    pairs=Counter(); deltas=[]
    for k in om.keys()&nm.keys():
      x,y=om[k],nm[k]; pairs[f"{x['outcome']}->{y['outcome']}"]+=1; deltas.append(y['final_hp']-x['final_hp'])
    report={"schema":1,"old":summary(old),"agency":summary(new),"by_policy":{},"by_biome_policy":{},"matched_outcomes":dict(pairs),"matched_hp_delta":round(mean(deltas),3),"paired_runs":len(deltas)}
    for policy in ["random","aggressive","defensive","tactical"]:
      report["by_policy"][policy]={"old":summary([r for r in old if r['policy']==policy]),"agency":summary([r for r in new if r['policy']==policy])}
      for biome in ["ashen_wastes","ember_marsh"]:
        report["by_biome_policy"][f"{biome}/{policy}"]={"old":summary([r for r in old if r['policy']==policy and r['biome']==biome]),"agency":summary([r for r in new if r['policy']==policy and r['biome']==biome])}
    Path(a.output).parent.mkdir(parents=True,exist_ok=True);Path(a.output).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8");print(json.dumps(report,ensure_ascii=False))
if __name__=="__main__":main()
