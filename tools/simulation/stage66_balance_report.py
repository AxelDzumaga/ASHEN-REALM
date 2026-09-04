#!/usr/bin/env python3
import argparse, json
from collections import Counter, defaultdict
from pathlib import Path

KEYS = ["combat_turns","damage_dealt","damage_taken","enemies_killed_before_intent","energy_generated","energy_spent","energy_wasted_at_cap","energy_lost_on_combat_end","energy_carried_between_combats","combat_start_energy","combat_starts_with_second_wind_energy","ember_slash_uses","second_wind_uses","healing_second_wind","first_ember_slash_turn","burn_damage","boss_burn_damage","burn_applications","burn_stack_sum","burn_stack_samples","burn_max_stacks","burn_ticks","burn_ticks_lost_on_death","burn_active_enemy_turns","boss_burn_active_turns"]

def load(path):
    with open(path, encoding="utf-8") as f: return [json.loads(x) for x in f if x.strip()]

def avg(rs, key): return sum(float(r.get(key,0)) for r in rs)/len(rs) if rs else 0
def summary(rs):
    out={}
    for policy in sorted({r["policy"] for r in rs}):
        p=[r for r in rs if r["policy"]==policy]; reached=[r for r in p if r["boss_outcome"]!="not_reached"]
        d={"runs":len(p),"win_rate":100*sum(r["outcome"]=="victory" for r in p)/len(p),"boss_reach":100*len(reached)/len(p),"boss_win":100*sum(r["boss_outcome"]=="victory" for r in reached)/len(reached) if reached else 0}
        for k in KEYS: d[k]=avg(p,k)
        d["burn_pct"]=100*d["burn_damage"]/d["damage_dealt"] if d["damage_dealt"] else 0
        d["average_burn_stacks"]=sum(r.get("burn_stack_sum",0) for r in p)/max(1,sum(r.get("burn_stack_samples",0) for r in p))
        d["first_slash_when_used"]=sum(r["first_ember_slash_turn"] for r in p if r.get("first_ember_slash_turn",-1)>=0)/max(1,sum(r.get("first_ember_slash_turn",-1)>=0 for r in p))
        d["biomes"]={b:100*sum(r["outcome"]=="victory" for r in p if r["biome"]==b)/sum(r["biome"]==b for r in p) for b in sorted({r["biome"] for r in p})}
        d["bosses"]={}
        for boss in ["ashen_warden","sunken_pyre"]:
            br=[r for r in reached if r.get("boss_id")==boss]
            d["bosses"][boss]={"runs":len(br),"win_rate":100*sum(r["boss_outcome"]=="victory" for r in br)/len(br) if br else 0,"turns":avg(br,"boss_turns"),"damage":avg(br,"boss_damage_dealt")}
        out[policy]=d
    burn=[r for r in rs if r.get("boons",{}).get("burning_strike",0)>0 and (r.get("boons",{}).get("relentless_flame",0)>0 or "inferno_rhythm" in r.get("synergies",[]))]
    none=[r for r in rs if r.get("boons",{}).get("burning_strike",0)==0 and r.get("boons",{}).get("relentless_flame",0)==0]
    out["build_cohorts"]={"high_burn":cohort(burn),"no_burn_investment":cohort(none)}
    return out

def cohort(rs):
    return {"runs":len(rs),"win_rate":100*sum(r["outcome"]=="victory" for r in rs)/len(rs) if rs else 0,"burn_damage":avg(rs,"burn_damage"),"burn_pct":100*avg(rs,"burn_damage")/avg(rs,"damage_dealt") if avg(rs,"damage_dealt") else 0,"stacks":sum(r.get("burn_stack_sum",0) for r in rs)/max(1,sum(r.get("burn_stack_samples",0) for r in rs)),"ticks":avg(rs,"burn_ticks"),"max_stacks":avg(rs,"burn_max_stacks"),"first_tile":avg([r for r in rs if r.get("first_burn_tile",-1)>=0],"first_burn_tile")}

def paired(a,b):
    aa={(r["seed"],r["biome"],r["policy"]):r for r in a}; bb={(r["seed"],r["biome"],r["policy"]):r for r in b}; out={}
    for policy in sorted({r["policy"] for r in a}):
        c=Counter(); hp=[]
        for k,x in aa.items():
            if k[2]!=policy or k not in bb: continue
            y=bb[k]; c[(x["outcome"],y["outcome"])]+=1; hp.append(y["final_hp"]-x["final_hp"])
        out[policy]={"vv":c[("victory","victory")],"vd":c[("victory","defeat")],"dv":c[("defeat","victory")],"dd":c[("defeat","defeat")],"hp_delta":sum(hp)/len(hp)}
    return out

def main():
    ap=argparse.ArgumentParser();ap.add_argument("baseline");ap.add_argument("candidates",nargs="+");ap.add_argument("--output",required=True);a=ap.parse_args();base=load(a.baseline);out={"baseline":summary(base)}
    for path in a.candidates:
        rows=load(path);out[Path(path).parent.name]={"summary":summary(rows),"paired":paired(base,rows)}
    Path(a.output).parent.mkdir(parents=True,exist_ok=True);Path(a.output).write_text(json.dumps(out,indent=2,ensure_ascii=False),encoding="utf-8");print(a.output)
if __name__=="__main__":main()
