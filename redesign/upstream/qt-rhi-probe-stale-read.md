# Draft: VideoLAN bug report (not posted)

Ready to paste into a new issue at https://code.videolan.org/videolan/vlc/-/issues once StickyGonzales
says so. It describes VLC's own code only (no Cone code in it), written for upstream readers. Cone
carries the fix (modules/gui/qt/qt.cpp, PR #131, redesign/PERF_AUDIT_NOTES.md).

---

**Title:** qt: the asynchronous RHI probe at start reads a local after its scope ended (ASan: stack-use-after-scope)

**Version:** VLC 4.0.0-dev (master, November 2026), Linux x86_64 (Ubuntu 22.04 build, GCC 11, Qt 6.8.3);
the code is the same on every platform.

**What happens:** in `modules/gui/qt/qt.cpp`, `Thread()`, once a graphics API is cached in the
settings (`graphics-api`, so on every start after the first), this block queues a lambda on the
event loop:

```cpp
const QVariant graphicsApiValue = p_intf->mainSettings->value(graphicsApiKey);
if (graphicsApiValue.isValid() && Q_LIKELY(graphicsApiValue.canConvert<int>()))
{
    QMetaObject::invokeMethod(&app, [&](){
        QQuickWindow::setGraphicsApi(static_cast<QSGRendererInterface::GraphicsApi>(graphicsApiValue.value<int>()));
        if (p_intf->mainSettings->value(graphicsApiRhiSoftwareKey).value<bool>())
            enableRhiSoftwareRenderer();
        ...
        if (graphicsApiValue.toInt() == QSGRendererInterface::OpenGL)
        ...
```

The lambda captures everything by reference. `graphicsApiValue` and `enableRhiSoftwareRenderer`
are locals of the enclosing `if` block, which has ended by the time the event loop runs the lambda
(`app.exec()` comes later). The lambda then reads a destroyed `QVariant`.

**How it shows:** with `-fsanitize=address` VLC aborts at the second start:

```
ERROR: AddressSanitizer: stack-use-after-scope on address ... READ of size 8 ... thread T6 (vlc-qt)
    #0 ... libqt_plugin.so (the lambda) ... QObject::event ... QCoreApplication::exec
Address ... is located in stack of thread T6 (vlc-qt) ... in frame Thread
    [4480, 4512) 'graphicsApiValue' (line 1435) <== Memory access at offset 4504 is inside this variable
```

Without ASan nothing visible happens in practice: the stack slot still holds the old value. It is
undefined behaviour all the same; a different compiler, optimisation level or stack layout could
make VLC pick a wrong graphics API at start.

**Steps:** build with `CFLAGS/CXXFLAGS=-fsanitize=address -fno-omit-frame-pointer`, start VLC with
any file once, quit, start it again.

**Fix:** capture the two locals by value:

```cpp
QMetaObject::invokeMethod(&app, [&, graphicsApiValue, enableRhiSoftwareRenderer](){
```

(`enableRhiSoftwareRenderer` is a captureless lambda, so its copy costs nothing.) With this change
the ASan build starts cleanly any number of times.
