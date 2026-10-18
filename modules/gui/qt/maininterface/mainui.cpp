#include "mainui.hpp"

#include <cassert>

#include "maininterface/navigationmodel.hpp"

#include "medialibrary/medialib.hpp"
#include "medialibrary/mlqmltypes.hpp"
#include "medialibrary/mlcustomcover.hpp"
#include "medialibrary/mlalbummodel.hpp"
#include "medialibrary/mlartistmodel.hpp"
#include "medialibrary/mlaudiomodel.hpp"
#include "medialibrary/mlgenremodel.hpp"
#include "medialibrary/mlurlmodel.hpp"
#include "medialibrary/mlmediamodel.hpp"
#include "medialibrary/mlvideomodel.hpp"
#include "medialibrary/mlrecentmediamodel.hpp"
#include "medialibrary/mlrecentvideomodel.hpp"
#include "medialibrary/mlfoldersmodel.hpp"
#include "medialibrary/mlvideogroupsmodel.hpp"
#include "medialibrary/mlvideofoldersmodel.hpp"
#include "medialibrary/mlplaylistlistmodel.hpp"
#include "medialibrary/mlplaylistmodel.hpp"
#include "medialibrary/mlplaylist.hpp"
#include "medialibrary/mlbookmarkmodel.hpp"
#include "medialibrary/rdsubfoldermodel.hpp"
#include "medialibrary/rdconcatmodel.hpp"
#include "medialibrary/rdcollectionmodel.hpp"
#include "medialibrary/rdlibrarystore.hpp"

#include "player/player_controller.hpp"
#include "player/player_controlbar_model.hpp"
#include "player/control_list_model.hpp"
#include "player/control_list_filter.hpp"
#include "player/delay_estimator.hpp"
#include "player/rd_effects.hpp"
#include "player/rd_presets.hpp"
#include "player/rd_seek_thumbnailer.hpp"
#include "player/rd_waveform.hpp"
#include "player/rd_waveform_item.hpp"
#include "player/rd_subtitle_lift.hpp"
#include "player/rd_subtitle_timeline.hpp"
#include "player/rd_subtitle_timeline_item.hpp"
#include "player/rd_now_playing.hpp"
#include "dialogs/toolbar/rd_profiles.hpp"
#include "player/rd_media_info.hpp"

#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "dialogs/toolbar/controlbar_profile.hpp"
#include "dialogs/redesign/hotkeys_model.hpp"
#include "dialogs/redesign/onboarding_helper.hpp"
#include "dialogs/redesign/settings/settings_catalog.hpp"
#include "dialogs/redesign/addsubtitles/add_subtitles.hpp"

#include "playlist/playlist_model.hpp"
#include "playlist/playlist_controller.hpp"

#include "util/brand.hpp"
#include "util/csdmenu.hpp"
#include "util/item_key_event_filter.hpp"
#include "util/imageluminanceextractor.hpp"
#include "util/keyhelper.hpp"
#include "style/systempalette.hpp"
#include "style/vlcicons.hpp"
#include "util/navigation_history.hpp"
#include "util/flickable_scroll_handler.hpp"
#include "util/kirigamiwheelhandler.hpp"
#include "util/color_svg_image_provider.hpp"
#include "util/effects_image_provider.hpp"
#include "util/vlcaccess_image_provider.hpp"
#include "util/csdbuttonmodel.hpp"
#include "util/vlctick.hpp"
#include "util/list_selection_model.hpp"
#include "util/ui_notifier.hpp"
#include "util/textureproviderobserver.hpp"
#include "util/textureproviderindirection.hpp"
#include "util/sgmanipulator.hpp"
#include "util/pointingtooltipattached.hpp"
#include "util/accessible_compat_attached.hpp"

#include "dialogs/help/aboutmodel.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "dialogs/dialogs/dialogmodel.hpp"
#ifdef UPDATE_CHECK
#include "dialogs/help/help.hpp" // UpdateModel
#endif
#include "util/vlchotkeyconverter.hpp"

#include "network/networkmediamodel.hpp"
#include "network/networkdevicemodel.hpp"
#include "network/networksourcesmodel.hpp"
#include "network/addonsmodel.hpp"
#include "network/standardpathmodel.hpp"

#include "menus/qml_menu_wrapper.hpp"
#include "menus/rd_menu_model.hpp"

#include "widgets/native/csdthemeimage.hpp"
#include "widgets/native/navigation_attached.hpp"
#include "widgets/native/viewblockingrectangle.hpp"
#if QT_VERSION < QT_VERSION_CHECK(6, 4, 0)
#include "widgets/native/doubleclickignoringitem.hpp"
#else
// QQuickItem already ignores double click, starting
// with Qt 6.4.0:
#define DoubleClickIgnoringItem QQuickItem
#endif

#include "videosurface.hpp"
#include "mainctx.hpp"
#ifdef _WIN32
#include "mainctx_win32.hpp"
#endif
#include "mainctx_submodels.hpp"

#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0) && defined(QT_DECLARATIVE_PRIVATE)
#include <QQuickRenderControl>
#include <QQuickWindow>

// Qt Quick's context matcher of QML shortcuts, exported for QtQuick.Templates (qquickshortcut.cpp)
typedef bool (*ShortcutContextMatcher)(QObject *, Qt::ShortcutContext);
ShortcutContextMatcher qt_quick_shortcut_context_matcher();
void qt_quick_set_shortcut_context_matcher(ShortcutContextMatcher matcher);

namespace {

ShortcutContextMatcher g_qtShortcutContextMatcher = nullptr;

/* redesign: from Qt 6.9, an application-wide QML shortcut only matches inside a visible window.
 * The X11 compositor draws the interface in an offscreen QQuickWindow (QQuickRenderControl) that
 * is never visible, so VLC's global shortcuts (ShortcutExt: Ctrl+P Settings, Ctrl+E, Ctrl+I,
 * Ctrl+L, F11 ...) never fired there. Such a shortcut matches when the window showing its
 * offscreen window is visible, as in Qt 6.8 (redesign/WEB_FIXES_1_NOTES.md) */
bool shortcutContextMatcher(QObject* object, Qt::ShortcutContext context)
{
    if (g_qtShortcutContextMatcher(object, context))
        return true;
    if (context != Qt::ApplicationShortcut)
        return false;
    for (QObject* parent = object; parent; parent = parent->parent())
    {
        if (const auto item = qobject_cast<QQuickItem*>(parent))
        {
            QWindow* shown = item->window() ? QQuickRenderControl::renderWindowFor(item->window())
                                            : nullptr;
            return shown && shown->isVisible();
        }
    }
    return false;
}

} // namespace
#endif

static bool g_qmlTypesAreRegistered = false;

using  namespace vlc::playlist;

MainUI::MainUI(qt_intf_t *p_intf, MainCtx *mainCtx, QWindow* interfaceWindow,  QObject *parent)
    : QObject(parent)
    , m_intf(p_intf)
    , m_mainCtx(mainCtx)
    , m_interfaceWindow(interfaceWindow)
{
    assert(m_intf);
    assert(m_mainCtx);
    assert(m_interfaceWindow);

    registerQMLTypes();

    // FIXME: Since Qt 6.6, Qt follows a different approach for scrolling. This new approach has
    //        caused a lot of frustration (QTBUG-116388, QTBUG-129948, QTBUG-120038). However,
    //        the previous scrolling behavior was not perfect either, so we have not been opting
    //        in to use the previous behavior. That being said, the new approach broke scrolling
    //        with views that has sections completely, so we don't have any option besides using
    //        the previous scrolling implementation. The new approach (b1766d9), `Flickable:
    //        Proportional wheel scrolling if deceleration is large` tells that the previous
    //        deceleration value was 5000. In this case, we use 10000 instead to not make scrolling
    //        as loose as it was before (which was apparently the main reason of coming up with the
    //        new approach). Setting this environment variable to any value lower than 15000
    //        reportedly (and evidently) brings back the old behavior, and does not continue
    //        using the new approach with the deceleration set (which is what we want to fix
    //        scrolling when there are sections).
    if constexpr (QT_VERSION >= QT_VERSION_CHECK(6, 6, 0))
    {
        const auto envFlickableWheelDeceleration = "QT_QUICK_FLICKABLE_WHEEL_DECELERATION";
        if (qEnvironmentVariableIsEmpty(envFlickableWheelDeceleration))
            qputenv(envFlickableWheelDeceleration, QByteArrayLiteral("10000"));
    }
}

MainUI::~MainUI()
{
    if (!m_engineBound)
    {
        // If the global engine is dead, we assume no other QML engine exists hence can clear the
        // types. Note that there may be multiple QML engines co-existing, but the global engine
        // is expected to outlive the others.
        clearQMLTypes();
    }
    else
    {
        // `QObject::destroyed()` is signalled just before the object dies, but subclass `QQmlEngine`
        // itself should be dead at that point anyway. This should prevent undefined behavior.
        connect(m_engineBound, &QObject::destroyed, &MainUI::clearQMLTypes);
    }
}

bool MainUI::setup(QQmlEngine* engine)
{
    m_engineBound = engine;

    if (m_mainCtx->hasMediaLibrary())
    {
        engine->addImageProvider(MLCustomCover::providerId, new MLCustomCover(m_mainCtx->getMediaLibrary()));
    }

#if QT_VERSION < QT_VERSION_CHECK(6, 5, 0)
    engine->addImportPath(":/qt/qml");
#endif

    if (!EffectsImageProvider::instance(engine, engine))
        new EffectsImageProvider(engine);
    engine->addImageProvider(QStringLiteral("svgcolor"), new SVGColorImageImageProvider());
    engine->addImageProvider(QStringLiteral("vlcaccess"), new VLCAccessImageProvider());
    if (m_seekThumbnailer)
        engine->addImageProvider(QLatin1String(RdSeekThumbnailer::providerId), m_seekThumbnailer->createImageProvider());

    m_component  = new QQmlComponent(engine, QStringLiteral("qrc:/qt/qml/VLC/MainInterface/MainInterface.qml"), QQmlComponent::PreferSynchronous, engine);
    if (m_component->isLoading())
    {
        msg_Warn(m_intf, "component is still loading");
    }

    if (m_component->isError())
    {
        for(auto& error: m_component->errors())
            msg_Err(m_intf, "qml loading %s %s:%u", qtu(error.description()), qtu(error.url().toString()), error.line());
#ifdef QT_STATIC
            assert( !"Missing qml modules from qt contribs." );
#else
            msg_Err( m_intf, "Install missing modules using your packaging tool" );
#endif
        return false;
    }

#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0) && defined(QT_DECLARATIVE_PRIVATE)
    // after the QML modules are loaded (QtQuick.Templates installs its own matcher), before the
    // interface creates its shortcuts
    if (qt_quick_shortcut_context_matcher() != &shortcutContextMatcher)
    {
        g_qtShortcutContextMatcher = qt_quick_shortcut_context_matcher();
        qt_quick_set_shortcut_context_matcher(&shortcutContextMatcher);
    }
#endif
    return true;
}

QQuickItem* MainUI::createRootItem()
{
    if (m_rootItem)
        return m_rootItem;

    assert(m_component);

    QObject* rootObject = m_component->create();

    if (m_component->isError())
    {
        for(auto& error: m_component->errors())
            msg_Err(m_intf, "qml loading %s %s:%u", qtu(error.description()), qtu(error.url().toString()), error.line());
        goto end;
    }

    if (rootObject == nullptr)
    {
        msg_Err(m_intf, "unable to create main interface, no root item");
        goto end;
    }
    m_rootItem = qobject_cast<QQuickItem*>(rootObject);
    if (!m_rootItem)
    {
        msg_Err(m_intf, "unexpected type of qml root item");
        goto end;
    }

end:
    delete m_component; // No need to have the component around anymore.
    return m_rootItem;
}

void MainUI::registerQMLTypes()
{
    assert(!g_qmlTypesAreRegistered);

    {
        const char* uri = "VLC.MainInterface";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.MainInterface
        qmlRegisterSingletonInstance<MainCtx>(uri, versionMajor, versionMinor, "MainCtx", m_mainCtx);
        // redesign: brand layer (util/brand.hpp)
        qmlRegisterSingletonInstance<BrandInfo>(uri, versionMajor, versionMinor, "Brand", new BrandInfo(this));
#ifdef _WIN32
        assert(dynamic_cast<MainCtxWin32*>(m_mainCtx));
        qmlRegisterAnonymousType<MainCtxWin32>(uri, versionMajor);
#endif
        qmlRegisterTypesAndRevisions<SearchCtx>(uri, versionMajor);
        qmlRegisterTypesAndRevisions<SortCtx>(uri, versionMajor);
        qmlRegisterUncreatableType<UINotifier>(uri, versionMajor, versionMinor, "UINotifier", "");
        qmlRegisterSingletonInstance<UINotifier>(uri, versionMajor, versionMinor, "UINotifier", new UINotifier(m_mainCtx, m_mainCtx));
        qmlRegisterSingletonInstance<NavigationHistory>(uri, versionMajor, versionMinor, "History", new NavigationHistory(this));
        qmlRegisterType<VideoSurface>(uri, versionMajor, versionMinor, "VideoSurface");
        qmlRegisterUncreatableType<BaseModel>( uri, versionMajor, versionMinor, "BaseModel", "Base Model is uncreatable." );
        qmlRegisterUncreatableType<VLCVarChoiceModel>(uri, versionMajor, versionMinor, "VLCVarChoiceModel", "generic variable with choice model" );
        qmlRegisterUncreatableType<CSDButton>(uri, versionMajor, versionMinor, "CSDButton", "");
        qmlRegisterUncreatableType<CSDButtonModel>(uri, versionMajor, versionMinor, "CSDButtonModel", "has CSD buttons and provides for communicating CSD events between UI and backend");
        qmlRegisterTypesAndRevisions<CSDMenu>( uri, versionMajor);
        qmlRegisterUncreatableType<NavigationAttached>( uri, versionMajor, versionMinor, "Navigation", "Navigation is only available via attached properties");
        qmlRegisterTypesAndRevisions<AboutModel>( uri, versionMajor );
#ifdef UPDATE_CHECK
        qmlRegisterSingletonInstance<UpdateModel>( uri, versionMajor, versionMinor, "UpdateModel", m_mainCtx->getUpdateModel() );
#endif

        qmlRegisterTypesAndRevisions<NavigationModel>( uri, versionMajor);
        qmlRegisterTypesAndRevisions<NavigationBarContextMenu>( uri, versionMajor );

        // Foreign types:
        qmlRegisterTypesAndRevisions<vlc::QAbstractProxyModelForeign>(uri, versionMajor);
        qmlRegisterTypesAndRevisions<vlc::QWindowForeign>(uri, versionMajor);
        qmlRegisterTypesAndRevisions<vlc::QScreenForeign>(uri, versionMajor);
        qmlRegisterTypesAndRevisions<vlc::QSortFilterProxyModelForeign>( uri, versionMajor );
        qmlRegisterTypesAndRevisions<vlc::QMessageBoxForeign>( uri, versionMajor );
#if QT_VERSION < QT_VERSION_CHECK(6, 5, 0)
        qmlRegisterTypesAndRevisions<vlc::QAbstractItemModelForeign>(uri, versionMajor); // Qt >= 6.5.0, import `QtQml.Models`.
#endif

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Dialogs";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Dialogs
        qmlRegisterType<VLCDialog>( uri, versionMajor, versionMinor, "VLCDialog" );
        assert(VLCDialogModel::getInstance<false>());
        qmlRegisterSingletonInstance<VLCDialogModel>(uri, versionMajor, versionMinor, "VLCDialogModel", VLCDialogModel::getInstance<false>());
        qmlRegisterUncreatableType<DialogId>( uri, versionMajor, versionMinor, "dialogId", "");
        assert(DialogsProvider::getInstance());
        qmlRegisterSingletonInstance<DialogsProvider>(uri, versionMajor, versionMinor, "DialogsProvider", DialogsProvider::getInstance());
        assert(DialogErrorModel::getInstance<false>());
        qmlRegisterSingletonInstance<DialogErrorModel>(uri, versionMajor, versionMinor, "DialogErrorModel", DialogErrorModel::getInstance<false>());
        // redesign: hotkey configuration of the Keyboard Shortcuts dialog
        qmlRegisterType<HotkeysModel>( uri, versionMajor, versionMinor, "HotkeysModel" );
        // redesign (W8.3): settings side of the onboarding
        qmlRegisterType<OnboardingHelper>( uri, versionMajor, versionMinor, "OnboardingHelper" );
        // redesign: VLC's options by Settings category, plugins, pickers (Settings pages)
        qmlRegisterSingletonInstance<SettingsCatalog>( uri, versionMajor, versionMinor, "SettingsCatalog",
                                                       new SettingsCatalog( m_intf, this ) );
        // redesign (W6.5): the Add Subtitles dialog's logic; it also adds the saved subtitles
        // when a video starts, so it exists from startup
        qmlRegisterSingletonInstance<AddSubtitles>( uri, versionMajor, versionMinor, "AddSubtitles",
                                                    new AddSubtitles( m_intf, this ) );
        qmlRegisterUncreatableType<AddSubtitlesModel>( uri, versionMajor, versionMinor, "AddSubtitlesModel", "" );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Menus";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Menus
        qmlRegisterType<StringListMenu>( uri, versionMajor, versionMinor, "StringListMenu" );
        qmlRegisterType<SortMenu>( uri, versionMajor, versionMinor, "SortMenu" );
        qmlRegisterType<SortMenuVideo>( uri, versionMajor, versionMinor, "SortMenuVideo" );
        qmlRegisterType<SortMenuAlbums>( uri, versionMajor, versionMinor, "SortMenuAlbums" );
        qmlRegisterType<QmlGlobalMenu>( uri, versionMajor, versionMinor, "QmlGlobalMenu" );
        qmlRegisterType<QmlMenuBar>( uri, versionMajor, versionMinor, "QmlMenuBar" );
        // redesign: VLC's menus drawn by the QML main menu and right-click menu
        qmlRegisterType<RdMenuModel>( uri, versionMajor, versionMinor, "RdMenuModel" );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Player";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Player
        qmlRegisterUncreatableType<TrackListModel>(uri, versionMajor, versionMinor, "TrackListModel", "available tracks of a media (audio/video/sub)" );
        qmlRegisterUncreatableType<TitleListModel>(uri, versionMajor, versionMinor, "TitleListModel", "available titles of a media" );
        qmlRegisterUncreatableType<ChapterListModel>(uri, versionMajor, versionMinor, "ChapterListModel", "available chapters of a media" );
        qmlRegisterUncreatableType<ProgramListModel>(uri, versionMajor, versionMinor, "ProgramListModel", "available programs of a media" );
        assert(m_intf->p_mainPlayerController);
        qmlRegisterSingletonInstance<PlayerController>(uri, versionMajor, versionMinor, "Player", m_intf->p_mainPlayerController);
        // redesign: effects and options shown in the settings sidebar, and the per-show presets
        RdEffects* effects = new RdEffects(m_intf, m_intf->p_mainPlayerController, this);
        qmlRegisterSingletonInstance<RdEffects>(uri, versionMajor, versionMinor, "RdEffects", effects);
        qmlRegisterSingletonInstance<RdPresets>(uri, versionMajor, versionMinor, "RdPresets",
                                                new RdPresets(m_intf, effects, this));
        // redesign: seek bar preview frames (P2-04)
        m_seekThumbnailer = new RdSeekThumbnailer(m_intf, m_intf->p_mainPlayerController, this);
        qmlRegisterSingletonInstance<RdSeekThumbnailer>(uri, versionMajor, versionMinor, "RdSeekThumbnailer",
                                                        m_seekThumbnailer);
        // redesign: waveform seek bar (P6-06): the playing file's waveform, and its bars
        qmlRegisterSingletonInstance<RdWaveform>(uri, versionMajor, versionMinor, "RdWaveform",
                                                 new RdWaveform(m_intf, m_intf->p_mainPlayerController, this));
        // redesign: subtitles above the control bar while it covers the picture (beta)
        qmlRegisterSingletonInstance<RdSubtitleLift>(uri, versionMajor, versionMinor, "RdSubtitleLift",
                                                     new RdSubtitleLift(m_intf->p_mainPlayerController, this));
        qmlRegisterType<RdWaveformItem>(uri, versionMajor, versionMinor, "RdWaveformItem");
        // redesign: subtitle timeline seek bar (P3-16): the selected external subtitle file's
        // cue times, and their blocks
        qmlRegisterSingletonInstance<RdSubtitleTimeline>(uri, versionMajor, versionMinor, "RdSubtitleTimeline",
                                                         new RdSubtitleTimeline(m_intf, m_intf->p_mainPlayerController, this));
        qmlRegisterType<RdSubtitleTimelineItem>(uri, versionMajor, versionMinor, "RdSubtitleTimelineItem");
        // redesign (W8.1b / W8.2): what the Customize Player items show about the playing
        // media, and the profiles (top bar layout, settings)
        qmlRegisterSingletonInstance<RdNowPlaying>(uri, versionMajor, versionMinor, "RdNowPlaying",
                                                   new RdNowPlaying(m_mainCtx, m_intf->p_mainPlayerController, this));
        qmlRegisterSingletonInstance<RdProfiles>(uri, versionMajor, versionMinor, "RdProfiles",
                                                 new RdProfiles(m_intf, m_mainCtx, this));
        // redesign: the Show Statistics and Show Metadata panels of the player (W4.3b)
        qmlRegisterType<RdInputStats>(uri, versionMajor, versionMinor, "RdInputStats");
        qmlRegisterType<RdMediaMeta>(uri, versionMajor, versionMinor, "RdMediaMeta");
        qmlRegisterTypesAndRevisions<TimedText>(uri, versionMajor);
        qmlRegisterType<PlayerHighResolutionTimeUpdater>(uri, versionMajor, versionMinor, "HighResolutionTimeUpdater");
        qmlRegisterUncreatableMetaObject(VLCTickForeign::staticMetaObject, uri, versionMajor, versionMinor, "VLCTick", "Not Instantiable" );
        qmlRegisterTypesAndRevisions<VLCDuration>(uri, versionMajor);
        qmlRegisterTypesAndRevisions<VLCTime>(uri, versionMajor);

        qmlRegisterType<QmlBookmarkMenu>( uri, versionMajor, versionMinor, "QmlBookmarkMenu" );
        qmlRegisterType<QmlProgramMenu>( uri, versionMajor, versionMinor, "QmlProgramMenu" );
        qmlRegisterType<QmlRendererMenu>( uri, versionMajor, versionMinor, "QmlRendererMenu" );
        qmlRegisterType<QmlSubtitleMenu>( uri, versionMajor, versionMinor, "QmlSubtitleMenu" );
        qmlRegisterType<QmlAudioMenu>( uri, versionMajor, versionMinor, "QmlAudioMenu" );
        qmlRegisterType<QmlAudioContextMenu>( uri, versionMajor, versionMinor, "QmlAudioContextMenu" );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.PlayerControls";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.PlayerControls
        qmlRegisterUncreatableType<ControlbarProfileModel>(uri, versionMajor, versionMinor, "ControlbarProfileModel", "");
        qmlRegisterUncreatableType<ControlbarProfile>(uri, versionMajor, versionMinor, "ControlbarProfile", "");
        qmlRegisterUncreatableType<PlayerControlbarModel>(uri, versionMajor, versionMinor, "PlayerControlbarModel", "");
        qmlRegisterUncreatableType<ControlListModel>( uri, versionMajor, versionMinor, "ControlListModel", "" );
        qmlRegisterType<ControlListFilter>(uri, versionMajor, versionMinor, "ControlListFilter");
        qmlRegisterSingletonType(uri, versionMajor, versionMinor, "PlayerListModel", PlayerControlbarModel::getPlaylistIdentifierListModel);


        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Playlist";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Playlist
        qmlRegisterUncreatableType<PlaylistItem>(uri, versionMajor, versionMinor, "playlistItem", "");
        qmlRegisterType<PlaylistListModel>( uri, versionMajor, versionMinor, "PlaylistListModel" );
        qmlRegisterType<PlaylistController>( uri, versionMajor, versionMinor, "PlaylistController" );
        qmlRegisterType<PlaylistContextMenu>( uri, versionMajor, versionMinor, "PlaylistContextMenu" );
        assert(m_intf->p_mainPlaylistController);
        qmlRegisterSingletonInstance<PlaylistController>(uri, versionMajor, versionMinor, "MainPlaylistController", m_intf->p_mainPlaylistController);

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Network";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Network
        qmlRegisterType<NetworkMediaModel>( uri, versionMajor, versionMinor, "NetworkMediaModel");
        qmlRegisterType<NetworkDeviceModel>( uri, versionMajor, versionMinor, "NetworkDeviceModel");
        qmlRegisterType<NetworkSourcesModel>( uri, versionMajor, versionMinor, "NetworkSourcesModel");
        qmlRegisterType<AddonsModel>( uri, versionMajor, versionMinor, "ServicesDiscoveryModel");
        qmlRegisterType<StandardPathModel>( uri, versionMajor, versionMinor, "StandardPathModel");
        qmlRegisterType<MLFoldersModel>( uri, versionMajor, versionMinor, "MLFolderModel");

        qmlRegisterType<NetworkMediaContextMenu>( uri, versionMajor, versionMinor, "NetworkMediaContextMenu" );
        qmlRegisterType<NetworkDeviceContextMenu>( uri, versionMajor, versionMinor, "NetworkDeviceContextMenu" );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Style";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Style
        qmlRegisterUncreatableType<ColorSchemeModel>(uri, versionMajor, versionMinor, "ColorSchemeModel", "");
        qmlRegisterType<ColorContext>(uri, versionMajor, versionMinor, "ColorContext");
        qmlRegisterUncreatableType<ColorProperty>(uri, versionMajor, versionMinor, "colorProperty", "");
        qmlRegisterType<SystemPalette>(uri, versionMajor, versionMinor, "SystemPalette");
        qmlRegisterTypesAndRevisions<VLCIcons>( uri, versionMajor );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Util";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Util
        qmlRegisterSingletonInstance<QmlKeyHelper>(uri, versionMajor, versionMinor, "KeyHelper", new QmlKeyHelper(this));
        qmlRegisterSingletonType<EffectsImageProvider>(uri, versionMajor, versionMinor, "Effects", EffectsImageProvider::instance);
        qmlRegisterUncreatableType<SVGColorImageBuilder>(uri, versionMajor, versionMinor, "SVGColorImageBuilder", "");
        qmlRegisterSingletonInstance<SVGColorImage>(uri, versionMajor, versionMinor, "SVGColorImage", new SVGColorImage(this));
        qmlRegisterSingletonInstance<VLCAccessImage>(uri, versionMajor, versionMinor, "VLCAccessImage", new VLCAccessImage(this));
        qmlRegisterType<DelayEstimator>( uri, versionMajor, versionMinor, "DelayEstimator" );
        qmlRegisterTypesAndRevisions<WheelToVLCConverter>( uri, versionMajor );

        qmlRegisterType<ImageLuminanceExtractor>( uri, versionMajor, versionMinor, "ImageLuminanceExtractor");

        qmlRegisterType<ItemKeyEventFilter>( uri, versionMajor, versionMinor, "KeyEventFilter" );

        // WARNING: This type is deprecated, do not use it.
        qmlRegisterType<FlickableScrollHandler>( uri, versionMajor, versionMinor, "VLCFlickableScrollHandler" );

        {
            auto funcRegisterScrollHandler = qmlRegisterType<DummyFlickableScrollHandler>;
            if (var_InheritBool(m_intf, "qt-use-scroll-handler"))
                funcRegisterScrollHandler = qmlRegisterType<Kirigami::WheelHandler>;

            funcRegisterScrollHandler( uri, versionMajor, versionMinor, "FlickableScrollHandler" );
        }

        qmlRegisterType<ListSelectionModel>( uri, versionMajor, versionMinor, "ListSelectionModel" );
        qmlRegisterType<DoubleClickIgnoringItem>( uri, versionMajor, versionMinor, "DoubleClickIgnoringItem" );
        qmlRegisterType<TextureProviderObserver>( uri, versionMajor, versionMinor, "TextureProviderObserver" );
        qmlRegisterType<TextureProviderIndirection>( uri, versionMajor, versionMinor, "TextureProviderIndirection" );
        qmlRegisterType<SGManipulator>( uri, versionMajor, versionMinor, "SGManipulator" );
        qmlRegisterTypesAndRevisions<AccessibleCompatAttached>( uri, versionMajor );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    {
        const char* uri = "VLC.Widgets";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.Widgets
        qmlRegisterType<CSDThemeImage>(uri, versionMajor, versionMinor, "CSDThemeImage");
        qmlRegisterType<ViewBlockingRectangle>( uri, versionMajor, versionMinor, "ViewBlockingRectangle" );
        qmlRegisterTypesAndRevisions<PointingToolTipAttached>( uri, versionMajor );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    if (m_mainCtx->hasMediaLibrary())
    {
        const char* uri = "VLC.MediaLibrary";
        const int versionMajor = 1;
        const int versionMinor = 0;

        // @uri VLC.MediaLibrary
        assert(m_mainCtx->getMediaLibrary());
        qmlRegisterSingletonInstance<MediaLib>(uri, versionMajor, versionMinor, "MediaLib", m_mainCtx->getMediaLibrary());

        qmlRegisterUncreatableType<MLItemId>( uri, versionMajor, versionMinor, "mediaId", "");
        qmlRegisterUncreatableType<MLBaseModel>( uri, versionMajor, versionMinor, "MLBaseModel", "ML Base Model is uncreatable." );
        qmlRegisterType<MLAlbumModel>( uri, versionMajor, versionMinor, "MLAlbumModel" );
        qmlRegisterType<MLArtistModel>( uri, versionMajor, versionMinor, "MLArtistModel" );
        qmlRegisterType<MLAudioModel>( uri, versionMajor, versionMinor, "MLAudioModel" );
        qmlRegisterType<MLGenreModel>( uri, versionMajor, versionMinor, "MLGenreModel" );
        qmlRegisterType<MLUrlModel>( uri, versionMajor, versionMinor, "MLUrlModel" );
        qmlRegisterType<MLMediaModel>( uri, versionMajor, versionMinor, "MLMediaModel" );
        qmlRegisterType<MLVideoModel>( uri, versionMajor, versionMinor, "MLVideoModel" );
        qmlRegisterType<MLRecentVideoModel>( uri, versionMajor, versionMinor, "MLRecentVideoModel" );
        qmlRegisterType<MLVideoGroupsModel>( uri, versionMajor, versionMinor, "MLVideoGroupsModel" );
        qmlRegisterType<MLVideoFoldersModel>( uri, versionMajor, versionMinor, "MLVideoFoldersModel" );
        qmlRegisterType<MLPlaylistListModel>( uri, versionMajor, versionMinor, "MLPlaylistListModel" );
        qmlRegisterType<MLPlaylistModel>( uri, versionMajor, versionMinor, "MLPlaylistModel" );
        qmlRegisterType<MLBookmarkModel>( uri, versionMajor, versionMinor, "MLBookmarkModel" );
        // redesign: the redesigned library (Phase 5)
        qmlRegisterUncreatableType<RdLibraryModel>( uri, versionMajor, versionMinor, "RdLibraryModel", "" );
        qmlRegisterType<RdSubfolderModel>( uri, versionMajor, versionMinor, "RdSubfolderModel" );
        qmlRegisterType<RdConcatModel>( uri, versionMajor, versionMinor, "RdConcatModel" );
        qmlRegisterType<RdCollectionModel>( uri, versionMajor, versionMinor, "RdCollectionModel" );
        qmlRegisterSingletonInstance<RdLibraryStore>( uri, versionMajor, versionMinor, "RdLibraryStore",
                                                      new RdLibraryStore(m_intf, m_mainCtx->getMediaLibrary(), this) );

        qmlRegisterType<NetworkMediaModel>( uri, versionMajor, versionMinor, "NetworkMediaModel");
        qmlRegisterType<NetworkDeviceModel>( uri, versionMajor, versionMinor, "NetworkDeviceModel");
        qmlRegisterType<NetworkSourcesModel>( uri, versionMajor, versionMinor, "NetworkSourcesModel");
        qmlRegisterType<AddonsModel>( uri, versionMajor, versionMinor, "ServicesDiscoveryModel");
        qmlRegisterType<MLFoldersModel>( uri, versionMajor, versionMinor, "MLFolderModel");
        qmlRegisterType<MLRecentMediaModel>( uri, versionMajor, versionMinor, "MLRecentMediaModel" );

        qmlRegisterType<PlaylistListContextMenu>( uri, versionMajor, versionMinor, "PlaylistListContextMenu" );
        qmlRegisterType<PlaylistMediaContextMenu>( uri, versionMajor, versionMinor, "PlaylistMediaContextMenu" );

        qmlRegisterModule(uri, versionMajor, versionMinor);
        qmlProtectModule(uri, versionMajor);
    }

    g_qmlTypesAreRegistered = true;
}

void MainUI::clearQMLTypes()
{
    qmlClearTypeRegistrations();
    g_qmlTypesAreRegistered = false;
}
