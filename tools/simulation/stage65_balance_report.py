#!/usr/bin/env python3
import argparse, json
from collections import defaultdict, Counter
from pathlib import Path

NUM = ["final_hp","combat_turns","damage_dealt","damage_taken","energy_generated","energy_spent","energy_wasted_at_cap","energy_lost_on_combat_end","turns_at_100_energy","turns_with_skill_available_but_not_used","ember_slash_opportunities","second_wind_opportunities","guard_opportunities","ember_slash_uses","ember_slash_damage","ember_slash_kills","ember_slash_intents_prevented","second_wind_uses","healing_second_wind","burn_damage","burn_ticks","burn_ticks_lost_on_death","burn_max_stacks","boss_burn_active_turns","warden_rebuke_intents","warden_rebuke_counters","warden_rebuke_damage","boss_entry_hp","boss_damage_dealt"]

def load(p):
    with open(p, encoding="utf-8") as f: return [json.loads(x) for x in f if x.strip()]

def summarize(rows):
    out={}
    groups=defaultdict(list)
    for r in rows: groups[r["policy"]].append(r)
    for policy, rs in groups.items():
        d={"runs":len(rs),"win_rate":100*sum(r["outcome"]=="victory" for r in rs)/len(rs),"boss_reach":100*sum(r["boss_outcome"]!="not_reached" for r in rs)/len(rs)}
        reached=[r for r in rs if r["boss_outcome"]!="not_reached"]
        d["boss_win"]=100*sum(r["boss_outcome"]=="victory" for r in reached)/len(reached) if reached else 0
        for k in NUM: d[k]=sum(float(r.get(k,0)) for r in rs)/len(rs)
        d["burn_pct"]=100*d["burn_damage"]/d["damage_dealt"] if d["damage_dealt"] else 0
        d["slash_damage_per_use"]=d["ember_slash_damage"]/d["ember_slash_uses"] if d["ember_slash_uses"] else 0
        d["rarity_fallbacks"]=sum(r.get("rarity_fallbacks",0) for r in rs)/len(rs)
        d["energy_flow"]={k:sum(r.get("energy_flow",{}).get(k,0) for r in rs)/len(rs) for k in ["CAP_WASTE","COMBAT_END_WASTE","SKILL_THRESHOLD","HELD_FOR_HEAL","HELD_FOR_ATTACK","NO_VALID_SKILL","POLICY_DECISION","OTHER"]}
        d["bosses"]={}
        for boss in ["ashen_warden","sunken_pyre"]:
            br=[r for r in reached if r.get("boss_id")==boss]
            d["bosses"][boss]={"reached":len(br),"win_rate":100*sum(r["boss_outcome"]=="victory" for r in br)/len(br) if br else 0,"entry_hp":sum(r["boss_entry_hp"] for r in br)/len(br) if br else 0,"turns":sum(r["boss_turns"] for r in br)/len(br) if br else 0}
        out[policy]=d
    return out

def paired(a,b):
    aa={(r["seed"],r["biome"],r["policy"]):r for r in a}; bb={(r["seed"],r["biome"],r["policy"]):r for r in b}
    out={}
    for p in sorted({r["policy"] for r in a}):
        c=Counter(); hp=[]
        for k,x in aa.items():
            if k[2]!=p or k not in bb: continue
            y=bb[k]; c[(x["outcome"],y["outcome"])]+=1; hp.append(y["final_hp"]-x["final_hp"])
        out[p]={"vv":c[("victory","victory")],"vd":c[("victory","defeat")],"dv":c[("defeat","victory")],"dd":c[("defeat","defeat")],"hp_delta":sum(hp)/len(hp)}
    return out

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("baseline"); ap.add_argument("candidates",nargs="+"); ap.add_argument("--output",required=True); a=ap.parse_args()
    base=load(a.baseline); result={"baseline":summarize(base),"candidates":{}}
    for p in a.candidates:
        rows=load(p); result[Path(p).parent.name]={"summary":summarize(rows),"paired":paired(base,rows)}
    Path(a.output).parent.mkdir(parents=True,exist_ok=True); Path(a.output).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding="utf-8")
    print(a.output)
if __name__=="__main__": main()
