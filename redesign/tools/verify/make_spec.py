#!/usr/bin/env python3
"""Builds the verification harness's design spec from the Figma file (redesign/tools/verify/spec).

    python redesign/tools/verify/make_spec.py            (from the repo root)

Inputs (all committed):
  redesign/reference/figma/figma_file.json   the Figma file (CC BY 4.0, Juxtopposed)
  redesign/reference/figma/styles.txt        the colour style values, dark and light
  redesign/FIGMA_FLOWS.md                    "Frame to PNG map": node id -> PNG name
  redesign/VIDEO_INDEX.md                    the rows and the Figma PNGs each row cites

Output: one JSON file per Figma frame (or component set) that a VIDEO_INDEX row cites, plus
index.json. The format is described in spec/README.md. The script only reads the inputs and
writes spec/; running it again gives the same files (sorted, no timestamps).
"""

import json
import math
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FIGMA = os.path.join(ROOT, "redesign", "reference", "figma", "figma_file.json")
STYLES = os.path.join(ROOT, "redesign", "reference", "figma", "styles.txt")
FLOWS = os.path.join(ROOT, "redesign", "FIGMA_FLOWS.md")
INDEX = os.path.join(ROOT, "redesign", "VIDEO_INDEX.md")
OUT = os.path.join(ROOT, "redesign", "tools", "verify", "spec")

FORMAT = 1
PNG_SCALE = 2  # the figma/ PNGs are 2x exports

# Light theme values Sticky set because the file's Light/FG/1 and Light/FG/2 equal the dark ones
# (Decision 33 in VIDEO_INDEX.md).
LIGHT_OVERRIDES = {"FG/1": "#111111", "FG/2": "#222222"}

# ---------------------------------------------------------------------------------------------
# Sample content: what the design shows as example media, library and user data. The harness
# masks these elements, because the test build shows other files, times and names.

TIME_RE = re.compile(r"(?<![\d.])-?\d{1,2}:\d{2}(:\d{2})?(:\d{3})?\*?(?![\d.])")
FILE_RE = re.compile(r"\.(mp4|mkv|avi|mov|webm|mp3|flac|wav|m4a|ogg|srt|ass|ssa|sub|vtt|idx)\b|"
                     r"S\d{2}E\d{2}|S\d{2}_", re.I)
COUNT_RE = re.compile(r"^\d+\s+(items?|bookmarks?|songs?|files?|videos?|episodes?|albums?|"
                      r"tracks?|folders?)\b", re.I)
# names of the design's sample library, media and user data (shows, songs, playlists, folders,
# presets, profiles), matched as substrings
SAMPLE_SUBSTRINGS = [
    "The Wand", "The_Wand", "DON’T BLINK", "juxtopposed", "untangle", "moonlight",
    "black bird", "My Songs", "Cool Playlist", "Cool Songs", "Coolest Songs", "Anime to Watch",
    "Anime Playlist", "Fav Episodes", "Loud and then Quiet Movies", "Winter (5 Years Later)",
    "Custom Preset 0", "Artist Name", "~/Videos", "(Movies)",
]
SAMPLE_EXACT = {"S01", "S02"}
# exact names that are sample content only inside a component: chapter titles and media tracks
# in the player panels, library folders in the library sidebar, preset and profile names
SAMPLE_IN_COMPONENT = {
    "Controls": {"Winter", "Spring", "Summer", "Fall", "English", "Japanese", "Track 1"},
    "sidebar": {"Films", "Anime", "TV Channels", "Podcasts", "Radio"},
    "Setting Preset": {"Anime"},
    "Profiles": {"Movies", "Work"},
}
# texts and icons that name the app: the "public" brand profile shows Cone there (Decision 48)
BRAND_RE = re.compile(r"\bVLC\b")
BRAND_ICONS = {"vlc"}

# words that say nothing about which row an element belongs to
STOPWORDS = set("""
a an and as at be by for from in into is it its of on or the to with without when while this
that these those their there then than not no new old only one two via per all any each both
frame group rectangle vector ellipse line instance property default state value direction none
yes icon wrapper component variant type text option options item items show shows shown she her
button buttons bar is are was can more also like used use uses using same just still next to
""".split())


def stem(word):
    word = word.lower()
    for suffix in ("ies",):
        if word.endswith(suffix) and len(word) > 4:
            return word[:-3] + "y"
    if word.endswith("s") and not word.endswith("ss") and len(word) > 3:
        return word[:-1]
    return word


# element layer names that stand for row words ("topbar" is the top bar of the rows)
SYNONYMS = {"topbar": {"top"}, "control": {"control"}, "miniplayer": {"mini", "player"},
            "seekbar": {"seek"}, "sidebar": {"sidebar"}}


def words(text):
    result = {stem(w) for w in re.findall(r"[A-Za-z][A-Za-z0-9]+", text or "")} - STOPWORDS
    for w in list(result):
        result |= SYNONYMS.get(w, set())
    return result


# ---------------------------------------------------------------------------------------------
# Inputs

def load_tokens():
    """Colour tokens from styles.txt: {"FG/1": {"dark": "#EAEAEA", "light": "#111111", ...}}."""
    tokens = {}
    pat = re.compile(r"^(Dark|Light)/(\S.*?)\s{2,}(#[0-9A-Fa-f]{6})(?:\s+(\d+)%)?\s*$")
    with open(STYLES, encoding="utf-8") as f:
        for line in f:
            m = pat.match(line.rstrip("\n"))
            if not m:
                continue
            theme, name, color, alpha = m.groups()
            t = tokens.setdefault(name, {})
            t[theme.lower()] = color.upper()
            if alpha:
                t[theme.lower() + "_alpha"] = int(alpha) / 100
    # the accent colour options (Decision 15): one value, the same in both themes
    with open(STYLES, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^(Accent/Option/\S+)\s+(#[0-9A-Fa-f]{6})", line)
            if m:
                tokens[m.group(1)] = {"dark": m.group(2).upper(), "light": m.group(2).upper()}
    for name, color in LIGHT_OVERRIDES.items():
        tokens[name]["light_figma"] = tokens[name]["light"]
        tokens[name]["light"] = color
        tokens[name]["light_source"] = "Decision 33"
    return tokens


def load_png_map():
    """FIGMA_FLOWS.md "Frame to PNG map": node id -> (layer name, kind, PNG file name)."""
    result = {}
    pat = re.compile(r"^\| (.+?) \| (\d+:\d+) \| (\w+) \| \d+x\d+ \| (.+?\.png) \|")
    with open(FLOWS, encoding="utf-8") as f:
        for line in f:
            m = pat.match(line)
            if m:
                result[m.group(2)] = (m.group(1), m.group(3), m.group(4))
    return result


def expand_ranges(text):
    """"Onboarding-1.png .. Onboarding-10.png" and "Player - customize-1.png .. customize-7.png"
    to every PNG of the range (the first one without a number when the range starts there)."""
    def repl(m):
        base, start, end = m.group(1).strip(), int(m.group(2) or 0), int(m.group(4))
        return ", ".join(base + (".png" if i == 0 else "-%d.png" % i) for i in range(start, end + 1))
    return re.sub(r"([^,;()]*?)(?:-(\d+))?\.png \.\. ([^,;()]*?)-(\d+)\.png", repl, text)


def load_rows(png_names):
    """VIDEO_INDEX rows: {n: {...}} and, per PNG name, the rows that cite it."""
    rows = {}
    cites = {}
    known = sorted(png_names, key=len, reverse=True)
    unknown = {}
    with open(INDEX, encoding="utf-8") as f:
        for line in f:
            if not re.match(r"^\| \d+ \|", line):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            n = int(cells[0])
            figma_col = cells[6]
            rows[n] = {"id": cells[1], "area": cells[3], "item": cells[4]}
            notes = " ".join(re.findall(r"\(([^)]*)\)", figma_col))
            figma_col = expand_ranges(figma_col).replace(" / ", ", ")
            rows[n]["_words"] = words(cells[3] + " " + cells[4] + " " + notes)
            for ref in re.findall(r"[^,;()]*?\.png", figma_col):
                ref = ref.strip()
                if not ref:
                    continue
                matched = []
                if "*" in ref:
                    rx = re.compile("^" + re.escape(ref).replace(r"\*", r"\d+") + "$")
                    matched = [p for p in known if rx.match(p)]
                elif ref in png_names:
                    matched = [ref]
                else:
                    # shortened references such as "customize-7.png"
                    matched = [p for p in known if p.endswith(ref)][:1]
                if not matched:
                    unknown.setdefault(ref, []).append(n)
                for p in matched:
                    cites.setdefault(p, set()).add(n)
    return rows, cites, unknown


# ---------------------------------------------------------------------------------------------
# Figma nodes

def r2(v):
    v = round(float(v), 2)
    return int(v) if v == int(v) else v


def hex_color(c):
    return "#%02X%02X%02X" % tuple(int(round(c[k] * 255)) for k in ("r", "g", "b"))


class Builder:
    def __init__(self, figma, tokens):
        self.figma = figma
        self.tokens = tokens
        self.styles = figma["styles"]
        self.components = figma["components"]
        self.sets = figma["componentSets"]
        self.token_by_dark = {}
        # theme tokens first, then the accent options, so #D37918 reads as Accent/Main
        for name, t in sorted(tokens.items(), key=lambda kv: kv[0].startswith("Accent/Option")):
            if "dark" in t and "dark_alpha" not in t:
                self.token_by_dark.setdefault(t["dark"], name)
        self.used_tokens = set()

    # colours -----------------------------------------------------------------------------
    def paint(self, p, style_id, theme):
        if p.get("visible", True) is False:
            return None
        kind = p["type"]
        if kind == "IMAGE":
            return {"type": "image"}
        out = {}
        if kind == "SOLID":
            style = self.styles.get(style_id, {}).get("name", "") if style_id else ""
            m = re.match(r"^(Dark|Light)/(.+)$", style)
            if m and m.group(2) in self.tokens:
                name = m.group(2)
                t = self.tokens[name]
                self.used_tokens.add(name)
                out = {"token": name, "dark": t["dark"], "light": t["light"]}
                if m.group(1).lower() != theme:
                    out["style_theme"] = m.group(1).lower()
            else:
                out = {"color": hex_color(p["color"])}
                if out["color"] in self.token_by_dark and theme == "dark":
                    out["same_as_token"] = self.token_by_dark[out["color"]]
            alpha = p.get("opacity", 1) * p["color"].get("a", 1)
            if alpha < 0.999:
                out["alpha"] = r2(alpha)
        elif kind.startswith("GRADIENT"):
            out = {"type": kind.lower(),
                   "stops": [{"pos": r2(s["position"]), "color": hex_color(s["color"]),
                              "alpha": r2(s["color"].get("a", 1))} for s in p["gradientStops"]]}
        else:
            out = {"type": kind.lower()}
        return out

    def paints(self, node, key, style_key, theme):
        style_id = node.get("styles", {}).get(style_key)
        result = [self.paint(p, style_id, theme) for p in node.get(key, [])]
        return [p for p in result if p]

    def effects(self, node):
        style_id = node.get("styles", {}).get("effect")
        if style_id and style_id in self.styles:
            return {"style": self.styles[style_id]["name"]}
        result = []
        for e in node.get("effects", []):
            if e.get("visible", True) is False:
                continue
            item = {"type": e["type"].lower(), "radius": r2(e.get("radius", 0))}
            if "color" in e:
                item["color"] = hex_color(e["color"])
                item["alpha"] = r2(e["color"].get("a", 1))
            if "offset" in e:
                item["offset"] = [r2(e["offset"]["x"]), r2(e["offset"]["y"])]
            if e.get("spread"):
                item["spread"] = r2(e["spread"])
            result.append(item)
        return result

    # components --------------------------------------------------------------------------
    def component_info(self, node):
        """(component set name, variant properties) of an instance or a component."""
        cid = node.get("componentId") if node["type"] == "INSTANCE" else node.get("id")
        comp = self.components.get(cid, {})
        set_id = comp.get("componentSetId")
        if set_id:
            set_name = self.sets.get(set_id, {}).get("name", "")
            props = dict(kv.split("=", 1) for kv in comp.get("name", "").split(", ") if "=" in kv)
            return set_name, set_id, props
        if comp:
            return comp.get("name", ""), None, {}
        return None, None, {}

    # elements ----------------------------------------------------------------------------
    def walk(self, node, origin, theme, ancestors, out, ctx):
        """Collects the visible elements under node. ancestors: meaningful names; ctx: info of the
        enclosing components (set names, set ids, seek track flag)."""
        if node.get("visible") is False or node.get("opacity", 1) == 0:
            return
        bb = node.get("absoluteBoundingBox")
        if not bb:
            return
        x, y = bb["x"] - origin[0], bb["y"] - origin[1]
        w, h = bb["width"], bb["height"]
        if x >= ctx["frame_w"] or y >= ctx["frame_h"] or x + w <= 0 or y + h <= 0:
            return  # fully outside the frame

        set_name, set_id, props = (None, None, {})
        if node["type"] == "INSTANCE":
            set_name, set_id, props = self.component_info(node)
        is_icon = set_name == "Icon"

        name = node["name"]
        generic = re.match(r"^(Frame|Group|Rectangle|Vector|Ellipse|Line|Union|Subtract|"
                           r"Polygon|Star|Intersect|Exclude)( \d+)?$", name) is not None
        label = set_name if set_name and name in (set_name, "Icon") else name
        if is_icon:
            label = "Icon:" + props.get("name", "")
        path = ancestors + ([] if generic else [label])

        fills = self.paints(node, "fills", "fill", theme)
        strokes = self.paints(node, "strokes", "stroke", theme) if node.get("strokeWeight") else []
        effects = self.effects(node)
        shape = node["type"] in ("RECTANGLE", "ELLIPSE", "VECTOR", "LINE", "STAR", "POLYGON",
                                 "BOOLEAN_OPERATION", "REGULAR_POLYGON")
        visual = bool(fills or strokes or effects or node["type"] == "TEXT" or shape
                      or node["type"] == "INSTANCE")

        comp_sets = ctx["sets"] + ([set_name] if set_name else [])
        comp_set_ids = ctx["set_ids"] + ([set_id] if set_id else [])
        in_seek = ctx["seek"]

        if visual:
            el = {"id": node["id"], "name": name, "type": node["type"].lower(),
                  "path": " / ".join(path) if path else name,
                  "bounds": [r2(x), r2(y), r2(w), r2(h)]}
            if x < 0 or y < 0 or x + w > ctx["frame_w"] + 0.01 or y + h > ctx["frame_h"] + 0.01:
                el["clipped"] = True
            if set_name:
                el["component"] = set_name
                if props:
                    el["variant"] = props
            if is_icon:
                el["icon"] = props.get("name", "")
            radius = node.get("rectangleCornerRadii")
            if radius and len(set(radius)) > 1:
                el["radius"] = [r2(v) for v in radius]
            elif node.get("cornerRadius"):
                el["radius"] = r2(node["cornerRadius"])
            if node.get("opacity", 1) < 0.999:
                el["opacity"] = r2(node["opacity"])
            if node["type"] == "TEXT":
                st = node.get("style", {})
                el["text"] = {
                    "content": node.get("characters", ""),
                    "font": st.get("fontFamily"),
                    "weight": st.get("fontWeight"),
                    "size": r2(st.get("fontSize", 0)),
                    "line_height": r2(st["lineHeightPx"]) if "lineHeightPx" in st else None,
                    "letter_spacing": r2(st.get("letterSpacing", 0)),
                    "align": st.get("textAlignHorizontal", "LEFT").lower(),
                }
                if st.get("textCase") and st["textCase"] != "ORIGINAL":
                    el["text"]["case"] = st["textCase"].lower()
                if fills:
                    el["text"]["color"] = fills[0] if len(fills) == 1 else fills
                    fills = []
            if fills:
                el["fills"] = fills
            if strokes:
                el["strokes"] = strokes
                el["stroke_weight"] = r2(node.get("strokeWeight", 0))
                el["stroke_align"] = node.get("strokeAlign", "INSIDE").lower()
            if effects:
                el["effects"] = effects
            translucent = any(f.get("alpha", 1) < 1 or "Transparent" in f.get("token", "")
                              for f in el.get("fills", []))
            if translucent or "blur" in json.dumps(effects):
                el["translucent"] = True

            mask = self.mask_reason(node, el, comp_sets, in_seek)
            if mask:
                el["mask"] = mask
            if self.is_brand(node, el):
                el["brand"] = True
            el["_words"] = self.element_words(el, path, comp_sets, props)
            el["_sets"] = comp_set_ids
            out.append(el)

        if is_icon or node["type"] in ("TEXT", "BOOLEAN_OPERATION"):
            return  # leaves: icons are checked as a whole
        # the seek track (the wide BG/B2 bar between the current time and the duration): the
        # elapsed fill, handle, waveform and marks inside it show the playback position
        seek_here = (not in_seek and ctx.get("time_row") and node["type"] == "FRAME"
                     and w >= 300 and any(f.get("token") == "BG/B2" for f in fills))
        children = node.get("children", [])
        time_row = any(c["type"] == "INSTANCE"
                       and self.component_info(c)[0] in ("Current Time", "Duration")
                       for c in children)
        sub = {"sets": comp_sets, "set_ids": comp_set_ids, "seek": in_seek or seek_here,
               "time_row": time_row, "frame_w": ctx["frame_w"], "frame_h": ctx["frame_h"]}
        for child in children:
            self.walk(child, origin, theme, path, out, sub)

    def mask_reason(self, node, el, comp_sets, in_seek):
        if any(f.get("type") == "image" for f in el.get("fills", [])):
            return "image"
        if in_seek:
            return "seek bar content"
        if node["type"] != "TEXT":
            return None
        text = node.get("characters", "")
        if TIME_RE.search(text) or re.search(r"\b\d+h \d+m\b", text):
            return "time"
        if FILE_RE.search(text):
            return "file name"
        if COUNT_RE.search(text):
            return "count"
        if text in SAMPLE_EXACT or any(s in text for s in SAMPLE_SUBSTRINGS):
            return "sample name"
        for set_name, names in SAMPLE_IN_COMPONENT.items():
            if text in names and set_name in comp_sets:
                return "sample name"
        return None

    def is_brand(self, node, el):
        if el.get("icon") in BRAND_ICONS:
            return True
        return node["type"] == "TEXT" and BRAND_RE.search(node.get("characters", "")) is not None

    def element_words(self, el, path, comp_sets, props):
        text = " ".join(path + comp_sets + list(props.values()))
        if "text" in el and "mask" not in el:
            text += " " + el["text"]["content"]
        if "icon" in el:
            text += " " + el["icon"]
        return words(text)


# ---------------------------------------------------------------------------------------------
# Rows per element

def assign_rows(elements, frame_rows, set_rows, rows, idf):
    """Suggested rows per element. Candidates: the rows that cite this frame's PNG and the rows
    that cite the PNG of a component set the element is (inside) an instance of. A candidate's
    score is the sum of the rarity (idf over all rows) of the words it shares with the element
    (name, path, component, variant, icon, unmasked text) and the row (area, Item, the note next
    to the PNG name). The element keeps the best candidates: score at least 1.5 and at least 60 %
    of the best one, at most 5."""
    for el in elements:
        candidates = set(frame_rows)
        for sid in el.pop("_sets"):
            candidates |= set_rows.get(sid, set())
        ew = el.pop("_words")
        scored = []
        for n in candidates:
            score = sum(idf.get(w, 0) for w in ew & rows[n]["_words"])
            if score > 0:
                scored.append((-score, n))
        scored.sort()
        if scored:
            best = -scored[0][0]
            keep = [n for s, n in scored[:5] if -s >= max(1.5, 0.6 * best)]
            if keep:
                el["rows"] = sorted(keep)


def slug(png):
    s = png[:-4].lower().replace("/", "-")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s + ".json"


def theme_of(node, styles):
    """"light" when at least a fifth of the colour styles in the frame are Light/ ones (a light
    frame still holds component instances whose own fills use Dark/ styles), "dark" otherwise."""
    count = {"Dark": 0, "Light": 0}

    def walk(n):
        for sid in n.get("styles", {}).values():
            name = styles.get(sid, {}).get("name", "")
            head = name.split("/", 1)[0]
            if head in count:
                count[head] += 1
        for c in n.get("children", []):
            walk(c)
    walk(node)
    total = count["Light"] + count["Dark"]
    return "light" if total and count["Light"] >= 0.2 * total else "dark"


def dump(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")


def main():
    with open(FIGMA, encoding="utf-8") as f:
        figma = json.load(f)
    tokens = load_tokens()
    png_map = load_png_map()
    rows, cites, unknown_refs = load_rows({v[2] for v in png_map.values()})
    builder = Builder(figma, tokens)
    df = {}
    for r in rows.values():
        for w in r["_words"]:
            df[w] = df.get(w, 0) + 1
    idf = {w: math.log(len(rows) / c) for w, c in df.items()}

    page = figma["document"]["children"][0]
    top = {n["id"]: n for n in page["children"]}
    missing = [i for i in png_map if i not in top]
    if missing or len(png_map) != len(top):
        sys.exit("FIGMA_FLOWS.md frame map does not match the Figma file: %s" % missing)

    set_rows = {}
    for node_id, (_, kind, png) in png_map.items():
        if kind == "component_set":
            set_rows[node_id] = cites.get(png, set())

    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".json"):
            os.remove(os.path.join(OUT, old))

    index_frames, unmapped = [], []
    used_rows = set()
    for node_id in [n["id"] for n in page["children"]]:
        layer, kind, png = png_map[node_id]
        node = top[node_id]
        frame_rows = sorted(cites.get(png, set()))
        if not frame_rows:
            unmapped.append({"node": node_id, "name": node["name"], "png": png, "kind": kind,
                             "reason": "no VIDEO_INDEX row cites it"})
            continue
        if kind == "text":
            unmapped.append({"node": node_id, "name": node["name"], "png": png, "kind": kind,
                             "reason": "a text label of the Figma page, not a frame",
                             "cited_by": frame_rows})
            continue
        used_rows |= set(frame_rows)
        bb = node["absoluteBoundingBox"]
        theme = theme_of(node, figma["styles"])
        spec = {"format": FORMAT, "node": node_id, "name": node["name"], "png": png,
                "png_scale": PNG_SCALE, "kind": kind, "size": [r2(bb["width"]), r2(bb["height"])],
                "theme": theme, "rows": frame_rows}
        total = masked = 0
        if kind == "component_set":
            variants = []
            for v in node.get("children", []):
                if v.get("visible") is False or "absoluteBoundingBox" not in v:
                    continue
                vb = v["absoluteBoundingBox"]
                _, _, props = builder.component_info(v)
                els = []
                ctx = {"sets": [node["name"]], "set_ids": [node_id], "seek": False,
                       "frame_w": vb["width"], "frame_h": vb["height"]}
                for child in v.get("children", []):
                    builder.walk(child, (vb["x"], vb["y"]), theme, [], els, ctx)
                assign_rows(els, frame_rows, set_rows, rows, idf)
                variant = {"node": v["id"], "name": v["name"], "props": props,
                           "bounds": [r2(vb["x"] - bb["x"]), r2(vb["y"] - bb["y"]),
                                      r2(vb["width"]), r2(vb["height"])]}
                variant["fills"] = builder.paints(v, "fills", "fill", theme)
                if v.get("cornerRadius"):
                    variant["radius"] = r2(v["cornerRadius"])
                variant["elements"] = els
                variants.append(variant)
                total += len(els)
                masked += sum(1 for e in els if "mask" in e)
            spec["variants"] = variants
        else:
            spec["background"] = builder.paints(node, "fills", "fill", theme)
            if any(p.get("type") == "image" for p in spec["background"]):
                spec["background_mask"] = "image"
            els = []
            ctx = {"sets": [], "set_ids": [], "seek": False,
                   "frame_w": bb["width"], "frame_h": bb["height"]}
            for child in node.get("children", []):
                builder.walk(child, (bb["x"], bb["y"]), theme, [], els, ctx)
            assign_rows(els, frame_rows, set_rows, rows, idf)
            spec["elements"] = els
            total, masked = len(els), sum(1 for e in els if "mask" in e)
        fname = slug(png)
        dump(os.path.join(OUT, fname), spec)
        index_frames.append({"file": fname, "node": node_id, "name": node["name"], "png": png,
                             "kind": kind, "size": spec["size"], "theme": theme,
                             "rows": frame_rows, "elements": total, "masked": masked})

    index = {
        "format": FORMAT,
        "source": {"figma_file": "redesign/reference/figma/figma_file.json",
                   "figma_name": figma.get("name"), "figma_version": figma.get("version"),
                   "figma_last_modified": figma.get("lastModified"),
                   "styles": "redesign/reference/figma/styles.txt",
                   "png_map": "redesign/FIGMA_FLOWS.md", "rows": "redesign/VIDEO_INDEX.md",
                   "generator": "redesign/tools/verify/make_spec.py"},
        "png_dir": "redesign/reference/figma",
        "png_scale": PNG_SCALE,
        "tokens": {k: tokens[k] for k in sorted(tokens)},
        "frames": index_frames,
        "unmapped_frames": unmapped,
        "rows": {str(n): {k: v for k, v in rows[n].items() if not k.startswith("_")}
                 for n in sorted(used_rows)},
        "rows_without_figma_frame": sorted(set(rows) - used_rows),
        "unknown_png_references": {k: sorted(v) for k, v in sorted(unknown_refs.items())},
    }
    dump(os.path.join(OUT, "index.json"), index)
    print("spec: %d frames (%d elements), %d top-level layers not mapped, %d rows covered"
          % (len(index_frames), sum(f["elements"] for f in index_frames), len(unmapped),
             len(used_rows)))


if __name__ == "__main__":
    main()
