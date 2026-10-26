#!/usr/bin/env python3
# release.yml: fills the release notes template.
#   release-notes.py <template> <output>
# Every {{NAME}} in the template is replaced by the environment variable RN_NAME; a placeholder
# without a value stops the release, so no note goes out half filled.
import os
import re
import sys

template_path, output_path = sys.argv[1], sys.argv[2]
with open(template_path, encoding="utf-8") as f:
    text = f.read()

missing = []


def fill(match):
    name = match.group(1)
    value = os.environ.get("RN_" + name, "")
    if not value:
        missing.append(name)
    return value


text = re.sub(r"\{\{([A-Z0-9_]+)\}\}", fill, text)
if missing:
    sys.exit("release-notes.py: no value for " + ", ".join(sorted(set(missing))))

with open(output_path, "w", encoding="utf-8") as f:
    f.write(text)
