# Compile-check VLC's QML with the real Qt QML engine (PySide6) before pushing a build.
# Catches the errors that make VLC refuse to load a QML type at runtime ("Type X unavailable",
# read-only or non-existent property assignments, unknown types, bad signal handlers, ...).
#
# How: mirrors the QML modules listed in modules/gui/qt/meson.build into an import tree, and
# stands in for the C++ types registered in maininterface/mainui.cpp with generated QML stubs
# (properties and signals parsed from the C++ headers; permissive, every property writable).
# The three C++ attached types (Navigation, AccessibleCompat, PointingToolTipAttached) are
# registered from Python. Files are only compiled, never instantiated.
# Qt matches VLC's contrib Qt (6.8.3); features VLC builds Qt without (Canvas, Shapes, ...) are
# flagged by a separate scan.
#
# Setup once (any folder outside the repo):
#   python -m venv qtvenv && qtvenv\Scripts\python -m pip install pyside6-essentials==6.8.3
# Run from the repo root, before every push that touches QML:
#   qtvenv\Scripts\python -I redesign\tools\qmlcheck.py . [files...]   (default: every module file)
# Expected: "errors: 1" (HighResolutionTimeWidget's value source cannot be stubbed) and "crashed: 0".
import os, re, shutil, sys

repo = os.path.abspath(sys.argv[1])
qt = os.path.join(repo, "modules", "gui", "qt")
import tempfile
# one tree per process: parallel runs (several agents, the crash-isolated workers) must not
# overwrite each other's files
import atexit
_tree = os.path.join(tempfile.gettempdir(), "vlc_qmlcheck_%d" % os.getpid())
imports = os.path.join(_tree, "imports")
atexit.register(shutil.rmtree, _tree, True)
os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PySide6.QtCore import QObject, QUrl, Property, Signal, QCoreApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent, QmlElement, QmlAttached, QmlUncreatable

# ---------------------------------------------------------------- C++ headers

headers = {}
for root, _, fs in os.walk(qt):
    for f in fs:
        if f.endswith((".hpp", ".h")):
            headers[os.path.join(root, f)] = None

def read(p):
    if headers.get(p) is None:
        headers[p] = open(p, encoding="utf-8", errors="replace").read()
    return headers[p]

def strip_comments(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)

class_cache = {}
def find_class(name):
    name = name.split("::")[-1]
    if name in class_cache:
        return class_cache[name]
    pat = re.compile(r"\bclass\s+(?:\w+\s+)?%s\b\s*(?:final\s*)?:\s*([^{;]+)\{" % re.escape(name))
    for p in headers:
        s = read(p)
        if name not in s:
            continue
        s = strip_comments(s)
        m = pat.search(s)
        if not m:
            continue
        # class body up to the matching brace
        i = m.end(); depth = 1
        while depth and i < len(s):
            depth += {"{": 1, "}": -1}.get(s[i], 0); i += 1
        body = s[m.end():i - 1]
        bases = [b.strip() for b in re.sub(r"<[^<>]*>", "", m.group(1)).split(",")]
        bases = [re.sub(r"^(public|protected|private|virtual)\s+", "", b).strip() for b in bases]
        info = {"body": body, "bases": bases}
        class_cache[name] = info
        return info
    class_cache[name] = None
    return None

QT_BASE_PROPS = {
    "QItemSelectionModel": ("model", "hasSelection", "currentIndex", "selection", "selectedIndexes"),
    "QSortFilterProxyModel": ("sourceModel", "filterRole", "filterRegularExpression", "filterCaseSensitivity",
                              "sortRole", "dynamicSortFilter", "filterKeyColumn", "recursiveFilteringEnabled",
                              "sortCaseSensitivity", "autoAcceptChildRows", "sortLocaleAware"),
    "QAbstractProxyModel": ("sourceModel",),
    "QIdentityProxyModel": ("sourceModel",),
    "QConcatenateTablesProxyModel": (),
    "QQmlParserStatus": (),
}

KEYWORDS = {"READ", "WRITE", "MEMBER", "NOTIFY", "RESET", "CONSTANT", "FINAL", "BINDABLE",
            "REVISION", "DESIGNABLE", "SCRIPTABLE", "STORED", "USER", "REQUIRED"}

def class_members(name, seen=None):
    """properties, signals and the Qt base class ('Item', 'Rectangle' or 'QtObject')"""
    seen = seen or set()
    props, sigs, qtbase = {}, {}, "QtObject"
    info = find_class(name)
    if not info or name in seen:
        return props, sigs, qtbase
    seen.add(name)
    for b in info["bases"]:
        bn = b.split("::")[-1]
        if bn in ("QQuickItem", "QQuickPaintedItem", "QQuickFramebufferObject"):
            qtbase = "Item"
        elif bn == "QQuickRectangle":
            qtbase = "Rectangle"
        elif bn == "QItemSelectionModel":
            qtbase = "ItemSelectionModel"
        elif bn.startswith("Q") and not find_class(bn):
            # properties of the Qt base classes VLC's types derive from
            for p in QT_BASE_PROPS.get(bn, ()):
                props[p] = True
            continue
        else:
            p2, s2, q2 = class_members(bn, seen)
            props.update(p2); sigs.update(s2)
            if q2 != "QtObject":
                qtbase = q2
    body = info["body"]
    for m in re.finditer(r"Q_PROPERTY\s*\((.*?)\)\s*(?=\n|Q_|$)", body, re.S):
        toks = re.sub(r"\s+", " ", m.group(1)).strip().split(" ")
        for k, t in enumerate(toks):
            if t in KEYWORDS:
                pname = toks[k - 1].lstrip("*&")
                if pname[:1].islower():
                    props[pname] = True
                break
    for m in re.finditer(r"\b(?!Q_PROPERTY\b)[A-Z_]*PROPERTY\s*\(\s*([^,()]+(?:<[^>]*>)?)\s*,\s*(\w+)", body):
        if m.group(2)[:1].islower():
            props[m.group(2)] = True
            sigs.pop(m.group(2) + "Changed", None)
    # signals sections
    for m in re.finditer(r"\b(?:signals|Q_SIGNALS)\s*:(.*?)(?=\b(?:public|private|protected)\b[^:;]*:|\Z)", body, re.S):
        for sm in re.finditer(r"\bvoid\s+(\w+)\s*\(([^)]*)\)", m.group(1)):
            args = [a.strip() for a in sm.group(2).split(",") if a.strip() and a.strip() != "void"]
            names = []
            for j, a in enumerate(args):
                a = a.split("=")[0].strip()
                w = re.findall(r"\w+", a)
                names.append(w[-1] if len(w) > 1 else "arg%d" % j)
            if sm.group(1)[:1].islower():
                sigs[sm.group(1)] = names
    return props, sigs, qtbase

# ---------------------------------------------------------------- registrations

mainui = strip_comments(open(os.path.join(qt, "maininterface", "mainui.cpp"), encoding="utf-8").read())
regs = []   # (uri, qml name, class, singleton)
uri = None
for line in mainui.splitlines():
    m = re.search(r'const char\*\s*uri\s*=\s*"([^"]+)"', line)
    if m:
        uri = m.group(1); continue
    m = re.search(r"qmlRegister(\w*)\s*<\s*([\w:]+)\s*>\s*\(([^;]*)", line)
    if m and uri:
        kind, cls, args = m.groups()
        if kind in ("TypesAndRevisions",):
            info = find_class(cls)
            if not info:
                continue
            n = re.search(r"QML_NAMED_ELEMENT\s*\(\s*(\w+)\s*\)", info["body"])
            if n:
                regs.append((uri, n.group(1), cls, False))
            elif re.search(r"\bQML_ELEMENT\b", info["body"]):
                regs.append((uri, cls.split("::")[-1], cls, False))
            continue
        if kind == "AnonymousType":
            continue
        n = re.findall(r'"([^"]*)"', args)
        if n:
            regs.append((uri, n[0], cls, kind.startswith("Singleton")))
        continue
    m = re.search(r'qmlRegisterSingletonType\s*\(\s*uri[^"]*"(\w+)"\s*,\s*([\w:]+)::', line)
    if m and uri:
        regs.append((uri, m.group(1), m.group(2), True))
    m = re.search(r'qmlRegisterUncreatableMetaObject\s*\(\s*(\w+)::staticMetaObject[^"]*"(\w+)"', line)
    if m and uri:
        regs.append((uri, m.group(2), m.group(1), True))

EXTRA = [("VLC.MainInterface", "QtWindow", "import QtQuick\nimport QtQuick.Window\nWindow {}\n"),
         ("VLC.MainInterface", "QtScreen", "import QtQuick\nQtObject {}\n"),
         ("VLC.MainInterface", "QtMessageBox", "import QtQuick\nQtObject {}\n"),
         ("VLC.MainInterface", "AbstractProxyModel", "import QtQuick\nQtObject { property var sourceModel }\n"),
         ("VLC.MainInterface", "QtSortFilterProxyModel",
          "import QtQuick\nQtObject { property var sourceModel; property var filterRole; property var filterRegularExpression;"
          " property var filterCaseSensitivity; property var sortRole; property var dynamicSortFilter; property var filterKeyColumn;"
          " property var recursiveFilteringEnabled; property var sortCaseSensitivity; property var filterWildcard }\n"),
         ("VLC.Util", "FlickableScrollHandler", None)]
ATTACHED = {"Navigation": "NavigationAttached", "AccessibleCompat": "AccessibleCompatAttached",
            "PointingToolTipAttached": "PointingToolTipAttached"}

# ---------------------------------------------------------------- import tree

meson = open(os.path.join(qt, "meson.build"), encoding="utf-8").read()
blocks = re.findall(r"qml_modules \+= \{(.*?)\n\}", meson[meson.index("qml_modules = []"):
                                                           meson.index("foreach module : qml_modules")], re.S)
# C++ value types (QML_VALUE_TYPE, e.g. vlcDuration, timedText) cannot be registered from Python:
# in the copies only, a property or signal parameter of one of them is read as `var`
value_types = set()
for root_dir, _, files in os.walk(qt):
    for f in files:
        if f.endswith((".hpp", ".h")):
            with open(os.path.join(root_dir, f), encoding="utf-8", errors="replace") as h:
                value_types |= set(re.findall(r"\bQML_VALUE_TYPE\s*\(\s*(\w+)\s*\)", h.read()))
value_type_re = re.compile(r"\b(property\s+)(%s)\b" % "|".join(sorted(value_types))) if value_types else None

def copy_qml(src, dst):
    with open(src, encoding="utf-8") as fsrc:
        text = fsrc.read()
    if value_type_re:
        text = value_type_re.sub(r"\1var", text)
        text = re.sub(r"(\bsignal\s+\w+\s*\()([^)]*)\)",
                      lambda m: m.group(1) + re.sub(r"\b(%s)(\s+\w+)" % "|".join(sorted(value_types)),
                                                    r"var\2", m.group(2)) + ")", text)
    with open(dst, "w", encoding="utf-8") as fdst:
        fdst.write(text)

shutil.rmtree(imports, ignore_errors=True)
copies = {}
original = {}
qmldirs = {}
for b in blocks:
    name = re.search(r"'name'\s*:\s*'([^']+)'", b).group(1)
    qmldirs.setdefault(name, ["module " + name])
    out = os.path.join(imports, *name.split("."))
    os.makedirs(out, exist_ok=True)
    for kind in ("sources", "singletons"):
        m = re.search(r"'%s'\s*:\s*files\((.*?)\)" % kind, b, re.S)
        for f in re.findall(r"'([^']+\.qml)'", m.group(1)) if m else []:
            src = os.path.join(qt, *f.split("/"))
            base = os.path.basename(f)
            if os.path.exists(src):
                # copied unchanged: a file that uses Popup, Control, Label, ... without importing
                # QtQuick.Controls(.Basic) or QtQuick.Templates fails in VLC too ("X is not a
                # type", seen on the PC in the toolbar editor), so it must fail here as well
                copy_qml(src, os.path.join(out, base))
                copies[os.path.normcase(src)] = os.path.join(out, base)
                original[os.path.normcase(src)] = src
            qmldirs[name].append(("singleton " if kind == "singletons" else "") + "%s 1.0 %s" % (base[:-4], base))

app = QGuiApplication(sys.argv[:1])
engine = QQmlEngine()

# names an Item / Rectangle / QtObject already has (a stub must not redeclare them)
builtin = {}
for t in ("Item", "Rectangle", "QtObject", "ItemSelectionModel"):
    c = QQmlComponent(engine)
    c.setData(("import QtQuick\nimport QtQml.Models\n%s {}\n" % t).encode(), QUrl())
    o = c.create()
    mo = o.metaObject()
    names = set(mo.property(i).name() for i in range(mo.propertyCount()))
    names |= set(bytes(mo.method(i).name()).decode() for i in range(mo.methodCount()))
    builtin[t] = names

registered = {}
for (u, qname, cls, singleton) in regs:
    if not singleton and qname not in ATTACHED:
        registered.setdefault(cls.split("::")[-1], (u, qname, cls))

def registered_ancestor(cls):
    todo = list((find_class(cls) or {"bases": []})["bases"])
    seen = set()
    while todo:
        b = todo.pop(0).split("::")[-1]
        if b in seen:
            continue
        seen.add(b)
        if b in registered:
            return registered[b]
        info = find_class(b)
        if info:
            todo += info["bases"]
    return None

stubbed = set()
for (u, qname, cls, singleton) in regs:
    if qname in ATTACHED or (u, qname) in stubbed:
        continue
    # a QML file of the same name in the module wins (e.g. Player.qml next to the Player singleton)
    if any(l.split(" ")[-3:-2] == [qname] or l.split(" ")[:1] == [qname] for l in qmldirs.get(u, [])):
        continue
    stubbed.add((u, qname))
    props, sigs, qtbase = class_members(cls)
    out = os.path.join(imports, *u.split("."))
    os.makedirs(out, exist_ok=True)
    qmldirs.setdefault(u, ["module " + u])
    head = (["pragma Singleton"] if singleton else []) + ["import QtQuick", "import QtQml.Models"]
    # derive from the stub of the nearest registered C++ base class, so a stub can go where its
    # base type is expected (e.g. a NetworkDeviceModel in a BaseModel property)
    taken = set(builtin[qtbase])
    anc = registered_ancestor(cls)
    if anc:
        bu, bq, bcls = anc
        head.append("import %s as StubBase" % bu)
        root = "StubBase." + bq
        bp, bs, _ = class_members(bcls)
        taken |= set(bp) | set(bs)
    else:
        root = qtbase
    lines = head + [root + " {"]
    for p in sorted(props):
        if p not in taken and p not in sigs:
            lines.append("    property var %s" % p)
    for s, a in sorted(sigs.items()):
        if s not in taken and not (s.endswith("Changed") and s[:-7] in props):
            lines.append("    signal %s(%s)" % (s, ", ".join("var " + x for x in a)))
    lines.append("}")
    fn = "Stub_%s.qml" % qname
    open(os.path.join(out, fn), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    qmldirs[u].append(("singleton " if singleton else "") + "%s 1.0 %s" % (qname, fn))

for (u, qname, text) in EXTRA:
    if text is None:
        props, sigs, _ = class_members("FlickableScrollHandler")
        text = ("import QtQuick\nQtObject {\n"
                + "".join("    property var %s\n" % p for p in sorted(props))
                + "".join("    signal %s()\n" % x for x in sorted(sigs) if x[:-7] not in props) + "}\n")
    fn = "Stub_%s.qml" % qname
    open(os.path.join(imports, *u.split("."), fn), "w", encoding="utf-8").write(text)
    qmldirs[u].append("%s 1.0 %s" % (qname, fn))

for u, lines in qmldirs.items():
    open(os.path.join(imports, *u.split("."), "qmldir"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

# attached types from Python, one namespace per module (QmlElement reads QML_IMPORT_NAME there)
ATTACHED_URI = {}
for (u, qname, cls, _) in regs:
    if qname in ATTACHED:
        ATTACHED_URI.setdefault(qname, u)
for qname, acls in ATTACHED.items():
    u = ATTACHED_URI.get(qname)
    if not u:
        continue
    props, sigs, _ = class_members(acls)
    src = ["from PySide6.QtCore import QObject, Property, Signal",
           "from PySide6.QtQml import QmlElement, QmlAttached, QmlUncreatable",
           "QML_IMPORT_NAME = %r" % u, "QML_IMPORT_MAJOR_VERSION = 1",
           "class A_%s(QObject):" % qname, "    _v = {}"]
    for p in sorted(props):
        src += ["    %sChanged = Signal()" % p,
                "    %s = Property('QVariant', lambda s: s._v.get(%r), lambda s, v: s._v.__setitem__(%r, v), notify=%sChanged)" % (p, p, p, p)]
    for s, a in sorted(sigs.items()):
        if not (s.endswith("Changed") and s[:-7] in props):
            src += ["    %s = Signal(%s)" % (s, ", ".join(["'QVariant'"] * len(a)))]
    src += ["    def __init__(self, parent=None):", "        super().__init__(parent); self._v = {}",
            "@QmlElement", "@QmlUncreatable('attached')", "@QmlAttached(A_%s)" % qname,
            "class %s(QObject):" % qname,
            "    @staticmethod", "    def qmlAttachedProperties(self, o):", "        return A_%s(o)" % qname]
    exec(compile("\n".join(src), "<attached %s>" % qname, "exec"), {"__name__": "att_" + qname})

engine.addImportPath(imports)

# ---------------------------------------------------------------- compile

targets = [os.path.normcase(os.path.abspath(t)) for t in sys.argv[2:]] or sorted(copies.keys())
back = {os.path.normcase(v): k for k, v in copies.items()}

def rel(t):
    return os.path.relpath(original.get(t, t), repo)

start = os.environ.get("QMLCHECK_START")
if start is not None:
    # worker: compile from targets[start], announcing each file (a Qt crash kills only this process)
    for k in range(int(start), len(targets)):
        print("@@", k, flush=True)
        c = QQmlComponent(engine, QUrl.fromLocalFile(copies.get(targets[k], targets[k])),
                          QQmlComponent.PreferSynchronous)
        if c.isError():
            for e in c.errors():
                f = e.url().toLocalFile()
                f = back.get(os.path.normcase(os.path.abspath(f)), f) if f else targets[k]
                print("%s:%d:%d: %s" % (rel(f), e.line(), e.column(), e.description()), flush=True)
    print("@@ done", flush=True)
    sys.exit(0)

import subprocess
n = 0; k = 0; crashed = []

# features VLC's contrib Qt is built without (contrib/src/qtdeclarative/rules.mak) and the style
# modules it leaves out: these load here but are "not a type" in VLC
MISSING = r"Canvas|Context2D|Shape|ShapePath|PathView|Path|PathLine|PathArc|PathQuad|PathCubic|PathSvg|" \
          r"AnimatedImage|AnimatedSprite|Sprite|SpriteSequence|Flipable|ParticleSystem|Emitter|ImageParticle|" \
          r"Calendar|MonthGrid|DayOfWeekRow|WeekNumberColumn|XmlListModel"
for t in targets:
    text = open(original.get(t, t), encoding="utf-8").read()
    for i, line in enumerate(text.splitlines(), 1):
        m = re.match(r"\s*(?:\w+\.)?(%s)\s*\{" % MISSING, line)
        if m:
            print("%s:%d:1: %s is not available in VLC's Qt build" % (rel(t), i, m.group(1))); n += 1
        m = re.match(r"\s*import\s+(QtQuick\.(?:Shapes|Particles|Controls\.(?:Material|Fusion|Universal|Imagine|Windows|macOS|iOS))|"
                     r"QtQuick\.Controls\s*$|QtQml\.XmlListModel|Qt5Compat\.\S+|QtQuick\.Timeline|QtQuick3D\S*|QtMultimedia|QtWebEngine|QtCharts)", line)
        if m:
            print("%s:%d:1: import %s is not available in VLC's Qt build" % (rel(t), i, m.group(1))); n += 1
while k < len(targets):
    env = dict(os.environ, QMLCHECK_START=str(k))
    pr = subprocess.run([sys.executable, "-I", os.path.abspath(__file__)] + sys.argv[1:], env=env,
                        capture_output=True, text=True, encoding="utf-8", errors="replace")
    last = k; done = False
    for line in pr.stdout.splitlines():
        if line.startswith("@@ "):
            if line == "@@ done":
                done = True
            else:
                last = int(line[3:])
        else:
            print(line); n += 1
    if done:
        break
    crashed.append(rel(targets[last]))
    k = last + 1
for c in crashed:
    print("%s: (Qt crashed while compiling this file; not checked)" % c)
print("errors:", n, "files:", len(targets), "crashed:", len(crashed))
