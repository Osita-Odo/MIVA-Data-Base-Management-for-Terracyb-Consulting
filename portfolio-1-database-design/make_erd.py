"""Generate erd.png from erd.dbml with Graphviz.

Usage:  python3 make_erd.py            (needs the Graphviz "dot" program)

Why a script: the ER image must always match the schema.
Reading the tables, columns and references straight from erd.dbml means
the picture is regenerated, not redrawn by hand, whenever the design changes.

Box colours group the tables:
  blue = organisation and geography, green = clients and assets,
  amber = engagements, red = security and compliance,
  purple = training and billing, grey = audit log (no relationships).
Lines run from the parent key to the child foreign key; the crow's foot
marks the "many" end.
"""
import html
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).parent
GROUPS = {
    'office': '#E8EEF5', 'state': '#E8EEF5', 'consultant': '#E8EEF5',
    'client': '#EAF3EC', 'client_site': '#EAF3EC', 'asset': '#EAF3EC',
    'service_line': '#FFF4E0', 'engagement': '#FFF4E0', 'engagement_staff': '#FFF4E0',
    'finding': '#FBE9E7', 'framework': '#FBE9E7', 'control': '#FBE9E7', 'control_assessment': '#FBE9E7',
    'training_session': '#F1ECF7', 'attendance': '#F1ECF7', 'invoice': '#F1ECF7', 'payment': '#F1ECF7',
    'audit_log': '#EEEEEE',
}

src = (HERE / 'erd.dbml').read_text()
tables = re.findall(r'Table (\w+) \{(.*?)\n\}', src, re.S)

dot = ['digraph ERD {',
       '  graph [rankdir=LR, splines=true, nodesep=0.45, ranksep=1.1, pad=0.3];',
       '  node [shape=plain, fontname="Arial", fontsize=11];',
       '  edge [color="#666666", dir=both, arrowtail=tee, arrowhead=crow, penwidth=1.1];']
relations = []
for name, body in tables:
    rows = []
    for line in body.split('\n'):
        m = re.match(r'(\w+) ([\w(),]+)(?: \[(.*)\])?$', line.strip())
        if not m or m.group(1) in ('indexes', 'Note'):
            continue
        col, typ, opts = m.group(1), m.group(2), m.group(3) or ''
        keys = []
        if 'pk' in re.split(r'[ ,]+', opts):
            keys.append('PK')
        ref = re.search(r'ref: > (\w+)\.(\w+)', opts)
        if ref:
            keys.append('FK')
            relations.append((ref.group(1), ref.group(2), name, col))
        if 'unique' in opts and 'PK' not in keys:
            keys.append('UK')
        name_cell = f'<B>{col}</B>' if 'PK' in keys else col
        key_cell = f'<FONT COLOR="#2F5D46"><B>{", ".join(keys)}</B></FONT>' if keys else ' '
        rows.append(f'<TR><TD ALIGN="LEFT" PORT="{col}">{name_cell}</TD>'
                    f'<TD ALIGN="LEFT"><FONT COLOR="#555555">{html.escape(typ)}</FONT></TD>'
                    f'<TD>{key_cell}</TD></TR>')
    label = (f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="4" COLOR="#888888" BGCOLOR="white">'
             f'<TR><TD COLSPAN="3" BGCOLOR="{GROUPS.get(name, "#EEEEEE")}"><B>{name}</B></TD></TR>{"".join(rows)}</TABLE>>')
    dot.append(f'  {name} [label={label}];')
for parent, pcol, child, ccol in relations:
    dot.append(f'  {parent}:{pcol} -> {child}:{ccol};')
dot.append('}')

subprocess.run(['dot', '-Tpng', '-Gdpi=150', '-o', str(HERE / 'erd.png')],
               input='\n'.join(dot), text=True, check=True)
print(f'erd.png written: {len(tables)} tables, {len(relations)} relationships')
