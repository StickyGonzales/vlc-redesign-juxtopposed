/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "compositor_platform.hpp"

#include <QApplication>
#include <QQuickView>
#include <QOperatingSystemVersion>

#include "maininterface/interface_window_handler.hpp"

#include <vlc_window.h>

#ifdef __APPLE__
#include <objc/runtime.h>
#include <objc/message.h>
#endif

using namespace vlc;

#ifdef __APPLE__
namespace {

// NSRect (CGRect) on 64-bit macOS
struct RdNSRect
{
    double x, y, w, h;
};

// an Objective-C message from C++ (this file is not Objective-C++). Only messages that return
// nothing, an object or a pointer: a struct return would need objc_msgSend_stret on x86_64
template <typename R = void, typename... Args>
R rdSend(id object, const char* selector, Args... args)
{
    using Send = R (*)(id, SEL, Args...);
    return reinterpret_cast<Send>(objc_msgSend)(object, sel_registerName(selector), args...);
}

// redesign (macOS, issue #69): the view the video output draws into. VLC's macOS outputs place
// their layers for an unflipped NSView (samplebufferdisplay: y = height - y - h) and paint
// nothing outside the picture; Qt's own view (QNSView) is flipped and has no background, so on a
// real Mac the picture could sit at the wrong height and the letterbox bands, where only the
// transparent interface window lies above, showed whatever was behind Cone. This plain NSView
// is unflipped, opaque black (as the video area of VLC.app) and follows the video window's size.
// Returns the view, owned by its superview, or nullptr
id rdMakeVideoView(id superview, double width, double height)
{
    const id viewClass = reinterpret_cast<id>(objc_getClass("NSView"));
    const id colorClass = reinterpret_cast<id>(objc_getClass("NSColor"));
    if (!superview || !viewClass || !colorClass)
        return nullptr;

    const id view = rdSend<id>(rdSend<id>(viewClass, "alloc"), "initWithFrame:",
                               RdNSRect{0, 0, width, height});
    if (!view)
        return nullptr;

    rdSend(view, "setWantsLayer:", static_cast<BOOL>(YES));
    if (const id layer = rdSend<id>(view, "layer"))
    {
        const id black = rdSend<id>(colorClass, "blackColor");
        rdSend(layer, "setBackgroundColor:", rdSend<void*>(black, "CGColor"));
        rdSend(layer, "setOpaque:", static_cast<BOOL>(YES));
    }
    // NSViewWidthSizable | NSViewHeightSizable: the video window's size, always
    rdSend(view, "setAutoresizingMask:", static_cast<unsigned long>(2 | 16));
    rdSend(superview, "addSubview:", view);
    rdSend(view, "release"); // the superview keeps it
    return view;
}

}
#endif


CompositorPlatform::CompositorPlatform(qt_intf_t *p_intf, QObject *parent)
    : CompositorVideo(p_intf, parent)
{

}

bool CompositorPlatform::init()
{
    // TODO: For now only qwindows and qdirect2d
    //       running on Windows 8+, and cocoa
    //       platforms are supported.

    const QString& platformName = qApp->platformName();

#ifdef _WIN32
    if (QOperatingSystemVersion::current() >= QOperatingSystemVersion::Windows8)
    {
        if (platformName == QLatin1String("windows") || platformName == QLatin1String("direct2d"))
        {
            // Video embedding with RHI often does not work, VirtualBox drivers may work, but VMWare
            // and Nvidia drivers (non-VM) don't. So we only allow this in non-RHI modes at the
            // moment. Note that using software rasterizer (such as D3D Warp), that can be requested
            // with `QSG_RHI_PREFER_SOFTWARE_RENDERER`, also does not work.
            if (qEnvironmentVariable("QT_QUICK_BACKEND", QStringLiteral("rhi")) == QLatin1String("rhi"))
                return false;

            return true; // Practically "software" and "openvg" modes (non-RHI).
        }
    }
#endif

#ifdef __APPLE__
    if (platformName == QLatin1String("cocoa") || platformName == QLatin1String("ios"))
        return true;
#endif

    return false;
}

bool CompositorPlatform::makeMainInterface(MainCtx *mainCtx, std::function<void (QQuickWindow *)> aboutToShowQuickWindowCallback)
{
    m_mainCtx = mainCtx;

    m_rootWindow = std::make_unique<QWindow>();

    m_videoWindow = new QWindow(m_rootWindow.get());

    m_quickWindow = new QQuickView(m_rootWindow.get());
    m_quickWindow->setResizeMode(QQuickView::SizeRootObjectToView);

    {
        // Transparency set-up:
        m_quickWindow->setColor(Qt::transparent);

        QSurfaceFormat format = m_quickWindow->format();
        format.setAlphaBufferSize(8);
        m_quickWindow->setFormat(format);
    }

    // Make sure the UI child window has the same size as the root parent window:
    connect(m_rootWindow.get(), &QWindow::widthChanged, m_quickWindow, &QWindow::setWidth);
    connect(m_rootWindow.get(), &QWindow::heightChanged, m_quickWindow, &QWindow::setHeight);

    m_quickWindow->create();

    const bool ret = commonGUICreate(m_rootWindow.get(), m_quickWindow, CompositorVideo::CAN_SHOW_PIP | CompositorVideo::HAS_ACRYLIC);

    m_quickWindow->setFlag(Qt::FramelessWindowHint);
    // Qt QPA Bug (qwindows, qdirect2d(?)): to trigger WS_EX_LAYERED set up.
    m_quickWindow->setOpacity(0.0);
    m_quickWindow->setOpacity(1.0);

    m_rootWindow->installEventFilter(this);

    if (aboutToShowQuickWindowCallback)
        aboutToShowQuickWindowCallback(m_quickWindow);

    m_rootWindow->setVisible(true);
    m_videoWindow->setVisible(true);
    m_quickWindow->setVisible(true);

    m_quickWindow->raise(); // Make sure quick window is above the video window.

#ifdef __APPLE__
    m_videoView = rdMakeVideoView(reinterpret_cast<id>(m_videoWindow->winId()),
                                  m_videoWindow->width(), m_videoWindow->height());
    if (!m_videoView)
        msg_Warn(m_intf, "macOS: no video view of its own, the video draws into Qt's view");
#endif

    return ret;
}

void CompositorPlatform::destroyMainInterface()
{
    commonIntfDestroy();
}

void CompositorPlatform::unloadGUI()
{
    m_rootWindow->removeEventFilter(this);
    m_interfaceWindowHandler.reset();
    m_quickWindow->setSource(QUrl());
    commonGUIDestroy();
}

bool CompositorPlatform::setupVoutWindow(vlc_window_t *p_wnd, VoutDestroyCb destroyCb)
{
    if (m_wnd)
        return false;

    commonSetupVoutWindow(p_wnd, destroyCb);

#ifdef __WIN32
    p_wnd->type = VLC_WINDOW_TYPE_HWND;
    p_wnd->handle.hwnd = reinterpret_cast<void*>(m_videoWindow->winId());

    return true;
#endif

#ifdef __APPLE__
    p_wnd->type = VLC_WINDOW_TYPE_NSOBJECT;
    p_wnd->handle.nsobject = m_videoView ? reinterpret_cast<id>(m_videoView)
                                         : reinterpret_cast<id>(m_videoWindow->winId());

    return true;
#endif

    vlc_assert_unreachable();
}

QWindow *CompositorPlatform::interfaceMainWindow() const
{
    return m_rootWindow.get();
}

QQuickWindow *CompositorPlatform::quickWindow() const
{
    return m_quickWindow.get();
}

Compositor::Type CompositorPlatform::type() const
{
    return Compositor::PlatformCompositor;
}

QQuickItem *CompositorPlatform::activeFocusItem() const
{
    assert(m_quickWindow);
    return m_quickWindow->activeFocusItem();
}

bool CompositorPlatform::eventFilter(QObject *watched, QEvent *event)
{
    // Forward drag events to the child quick window,
    // as it is not done automatically by Qt with
    // nested windows:
    if (m_quickWindow && watched == m_rootWindow.get())
    {
        switch (event->type()) {
        case QEvent::DragEnter:
        case QEvent::DragLeave:
        case QEvent::DragMove:
        case QEvent::DragResponse:
        case QEvent::Drop:
            QApplication::sendEvent(m_quickWindow, event);
            return true;
        default:
            break;
        };
    }
    return false;
}

void CompositorPlatform::commitSurface()
{
    if (!m_videoWindow)
        return;

    if (m_pendingPosition && m_pendingSize)
    {
        m_videoWindow->setGeometry(m_pendingPosition->x(), m_pendingPosition->y(),
                                   m_pendingSize->width(), m_pendingSize->height());
        m_pendingPosition.reset();
        m_pendingSize.reset();
    }
    else
    {
        if (m_pendingSize)
        {
            m_videoWindow->resize(*m_pendingSize);
            m_pendingSize.reset();
        }
        else if (m_pendingPosition)
        {
            m_videoWindow->setPosition(*m_pendingPosition);
            m_pendingPosition.reset();
        }
    }
}

int CompositorPlatform::windowEnable(const vlc_window_cfg_t *)
{
    commonWindowEnable();
    return VLC_SUCCESS;
}

void CompositorPlatform::windowDisable()
{
    commonWindowDisable();
}

void CompositorPlatform::onSurfacePositionChanged(const QPointF &position)
{
    const QPointF point = position / m_videoWindow->devicePixelRatio();
    m_pendingPosition = QPoint{static_cast<int>(point.x()), static_cast<int>(point.y())};
}

void CompositorPlatform::onSurfaceSizeChanged(const QSizeF &size)
{
    const QSizeF area = (size / m_videoWindow->devicePixelRatio());
    m_pendingSize = QSize{static_cast<int>(std::ceil(area.width())), static_cast<int>(std::ceil(area.height()))};
}
