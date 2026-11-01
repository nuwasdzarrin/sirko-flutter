#!/usr/bin/env bash
# Cetak elemen ber-teks pada layar aktif (bantu menulis selector flow).
source "$(dirname "$0")/env.sh"
maestro --device "$DEVICE" hierarchy --compact 2>/dev/null | python -c "
import csv,sys,re
for row in csv.reader(sys.stdin):
    if len(row)<3: continue
    a=row[2]
    if 'systemui' in a: continue
    keep=[p.strip() for p in a.split('; ') if p.split('=')[0] in ('text','accessibilityText','hintText','bounds','checked','selected')]
    if any(k.startswith(('text','accessibilityText','hintText')) for k in keep):
        print(' | '.join(keep).replace('\n','\\n'))
"
