"""Rank candidate demo queries against the sample contacts with the real model.

Reuses the exact contact passage texts in texts.json and the same MiniLM as the
app, so the top result predicts what the semantic tier will surface in the UI.
Run:  tool/embed/.venv/Scripts/python tool/embed/rank.py
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"

CANDIDATES = [
    # cross-language ZH -> EN
    "金融業", "找懂資安的人", "需要做產品設計的人", "想認識創投",
    "誰能幫我介紹新創創辦人", "做機器學習的工程師", "公部門金融窗口",
    "懂向量搜尋的人", "行動App上線體驗設計", "早期募資",
    # EN paraphrase / synonym
    "someone who can help us raise a seed round",
    "a designer for our app's first-run experience",
    "who can introduce me to startup founders",
    "expert in on-prem data privacy",
    "public sector banking contact",
    "help me with enterprise AI deployment",
    # lexical-friendly
    "Taiwan finance", "AI ecosystem", "product designer",
    # deliberate no-match
    "marine biologist studying coral reefs",
]

def l2(v):
    n = math.sqrt(sum(x*x for x in v));  return [x/n for x in v] if n else v
def cos(a,b): return sum(x*y for x,y in zip(a,b))

def label(passage):  # first token(s) identify the contact
    return passage.split(" notes")[0][:22]

def main():
    from fastembed import TextEmbedding
    rows = json.load(open(os.path.join(HERE,"texts.json"), encoding="utf-8"))
    passages = [r["text"] for r in rows if r["kind"]=="passage"]
    queries = CANDIDATES + ["需要懂資料落地與企業內部署的資安顧問"]
    m = TextEmbedding(model_name=MODEL)
    pvecs = [l2(list(map(float,v))) for v in m.embed(passages)]
    qvecs = [l2(list(map(float,v))) for v in m.embed(queries)]
    out = ["=== CONTACT ROSTER (passage texts) ==="]
    for p in passages:
        out.append("  - " + p[:90])
    out.append("\n=== QUERY -> TOP 3 (cosine) ===")
    for q, qv in zip(queries, qvecs):
        scored = sorted(((cos(qv,pv), label(p)) for p,pv in zip(passages,pvecs)), reverse=True)
        top = "  |  ".join(f"{lbl} {s:.2f}" for s,lbl in scored[:3])
        out.append(f"{q:<38} -> {top}")
    text = "\n".join(out)
    with open(os.path.join(HERE,"rank_out.txt"),"w",encoding="utf-8") as f:
        f.write(text)
    print(text)

if __name__ == "__main__":
    main()
