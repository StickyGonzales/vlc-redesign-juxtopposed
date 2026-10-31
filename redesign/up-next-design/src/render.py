# Offscreen renderer for the Up Next design mockups: Qt 6.8 Quick, Inter, the redesign's own
# two-tone SVG icons (color1 #FF00FF = main, color2 #00FFFF = Accent/DIm) and the Figma tokens.
import sys, os
from PySide6.QtCore import QUrl, QTimer, QByteArray, QSize, Qt
from PySide6.QtGui import QGuiApplication, QImage, QPainter
from PySide6.QtQuick import QQuickView, QQuickImageProvider
from PySide6.QtQml import QQmlImageProviderBase
from PySide6.QtSvg import QSvgRenderer

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
ICONS = os.path.join(ROOT, 'modules/gui/qt/pixmaps/redesign')
LOGO = os.path.join(ROOT, 'modules/gui/qt/pixmaps/brand/public/cone-logo-24.svg')

DARK = dict(isDark=True, fg1='#EAEAEA', fg2='#C6C6C6', fgA1='#969696', fgA2='#8F8F8F', fgA3='#6B6B6B',
            fgA4='#404040', fgB1='#161616', accent='#D37918', accentBright='#FC9729', accentDim='#AB6314',
            bgAccentBright='#371F06', bgAccentDark='#1A1611', bgA1='#222222', bgA2='#1F1F1F',
            bgA3='#1B1B1B', bgA4='#191919', bgA5='#151515', bgB1='#0E0E0E', bgB2='#090909',
            divBright='#373737', divDim='#222222', video='#000000', shadow='#75000000')
LIGHT = dict(isDark=False, fg1='#111111', fg2='#222222', fgA1='#3C3C3C', fgA2='#2E2E2E', fgA3='#6B6B6B',
             fgA4='#3B3B3B', fgB1='#161616', accent='#E8851A', accentBright='#FFA13B', accentDim='#965916',
             bgAccentBright='#D8BA9A', bgAccentDark='#C6AB89', bgA1='#EDEDED', bgA2='#DDDDDD',
             bgA3='#D5D5D5', bgA4='#B3B3B3', bgA5='#888888', bgB1='#E7E7E7', bgB2='#DEDEDE',
             divBright='#9B9B9B', divDim='#ACACAC', video='#000000', shadow='#40000000')

class Icons(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQmlImageProviderBase.Image)
    # id: name/c1/c2 (hex without #); size from sourceSize
    def requestImage(self, id, size, requested):
        name, c1, c2 = (id.split('/') + ['', ''])[:3]
        if not name:
            img = QImage(1, 1, QImage.Format_ARGB32_Premultiplied); img.fill(Qt.transparent); return img
        path = LOGO if name == 'cone' else os.path.join(ICONS, name + '.svg')
        data = open(path).read()
        if c1: data = data.replace('#FF00FF', '#' + c1).replace('#ff00ff', '#' + c1)
        if c2: data = data.replace('#00FFFF', '#' + c2).replace('#00ffff', '#' + c2)
        if name == 'cone' and c1: data = data.replace('#D37918', '#' + c1)
        r = QSvgRenderer(QByteArray(data.encode()))
        w = requested.width() if requested.width() > 0 else 24
        h = requested.height() if requested.height() > 0 else w
        img = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
        img.fill(Qt.transparent)
        p = QPainter(img); r.render(p); p.end()
        return img

def main():
    qml, out, w, h, theme = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    app = QGuiApplication(sys.argv[:1])
    v = QQuickView()
    icons = Icons()
    v.engine().addImageProvider('icon', icons)
    t = dict(DARK if theme == 'dark' else LIGHT)
    v.rootContext().setContextProperty('T', t)
    v.rootContext().setContextProperty('ASSETS', QUrl.fromLocalFile(os.path.dirname(os.path.abspath(__file__)) + '/assets/').toString())
    v.engine().addImportPath(os.path.dirname(os.path.abspath(__file__)))
    v.setResizeMode(QQuickView.SizeRootObjectToView)
    v.resize(w, h)
    v.setSource(QUrl.fromLocalFile(qml))
    if v.status() == QQuickView.Error:
        for e in v.errors(): print(e.toString())
        sys.exit(1)
    v.show()
    def grab():
        v.grabWindow().save(out); app.quit()
    QTimer.singleShot(900, grab)
    app.exec()

main()
