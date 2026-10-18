/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "rd_now_playing.hpp"

#include <QDir>
#include <QStringList>
#include <QUrl>

#include <vlc_media_library.h>
#include <vlc_url.h>

#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlhelper.hpp"
#include "player/player_controller.hpp"

namespace {

// a library with many playlists is not read through for one name
constexpr size_t kMaxPlaylists = 200;

// the library keeps the MRL VLC made from the path (vlc_path2uri encodes more characters than
// QUrl, e.g. the brackets of "Show (2020).mkv"): both spellings are asked
QList<QByteArray> mrlCandidates(const QUrl& url, const QString& mrl)
{
    QList<QByteArray> candidates { mrl.toUtf8() };
    if (url.isLocalFile())
    {
        if (char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(url.toLocalFile())), "file"))
        {
            const QByteArray vlcMrl(uri);
            free(uri);
            if (!candidates.contains(vlcMrl))
                candidates.append(vlcMrl);
        }
    }
    return candidates;
}

} // namespace

RdNowPlaying::RdNowPlaying(MainCtx* ctx, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_ctx(ctx)
    , m_player(player)
{
    connect(m_player, &PlayerController::inputChanged, this, &RdNowPlaying::onInputChanged);
    onInputChanged();
}

void RdNowPlaying::onInputChanged()
{
    const QUrl url = m_player->getUrl();
    const QString mrl = url.toString(QUrl::FullyEncoded);
    if (mrl == m_mrl)
        return;
    m_mrl = mrl;

    // the path's last two parts, without the query of a stream address
    const QStringList parts = url.path(QUrl::FullyDecoded).split(QLatin1Char('/'), Qt::SkipEmptyParts);
    m_fileName = parts.isEmpty() ? QString() : parts.last();
    m_folderName = (url.isLocalFile() && parts.size() >= 2) ? parts.at(parts.size() - 2) : QString();
    emit mediaChanged();

    ++m_generation;
    m_queriedMrl.clear();
    setLibraryValues(0, false, {});
    if (m_watchers > 0)
        query();
}

void RdNowPlaying::watch()
{
    if (++m_watchers == 1 && m_queriedMrl != m_mrl)
        query();
}

void RdNowPlaying::unwatch()
{
    if (m_watchers > 0)
        --m_watchers;
}

void RdNowPlaying::query()
{
    MediaLib* mediaLib = m_ctx ? m_ctx->getMediaLibrary() : nullptr;
    if (!mediaLib || m_mrl.isEmpty())
        return;
    m_queriedMrl = m_mrl;

    struct Ctx {
        int64_t mediaId = 0;
        bool favorite = false;
        QString playlistName;
    };

    const QList<QByteArray> candidates = mrlCandidates(m_player->getUrl(), m_mrl);
    const int generation = m_generation;
    mediaLib->runOnMLThread<Ctx>(this,
    [candidates](vlc_medialibrary_t* ml, Ctx& ctx) {
        ml_unique_ptr<vlc_ml_media_t> media;
        for (const QByteArray& mrl : candidates)
        {
            media.reset(vlc_ml_get_media_by_mrl(ml, mrl.constData()));
            if (media)
                break;
        }
        if (!media)
            return;
        ctx.mediaId = media->i_id;
        ctx.favorite = media->b_is_favorite;

        vlc_ml_query_params_t params = vlc_ml_query_params_create();
        params.i_sort = VLC_ML_SORTING_ALPHA;
        params.i_nbResults = kMaxPlaylists;
        ml_unique_ptr<vlc_ml_playlist_list_t> playlists(
            vlc_ml_list_playlists(ml, &params, VLC_ML_PLAYLIST_TYPE_ALL));
        if (!playlists)
            return;
        for (const vlc_ml_playlist_t& playlist : ml_range_iterate<vlc_ml_playlist_t>(playlists))
        {
            ml_unique_ptr<vlc_ml_media_list_t> items(vlc_ml_list_playlist_media(ml, nullptr, playlist.i_id));
            if (!items)
                continue;
            for (const vlc_ml_media_t& item : ml_range_iterate<vlc_ml_media_t>(items))
            {
                if (item.i_id == ctx.mediaId)
                {
                    ctx.playlistName = qfu(playlist.psz_name);
                    return;
                }
            }
        }
    },
    [this, generation](quint64, Ctx& ctx) {
        if (generation != m_generation)
            return;
        setLibraryValues(ctx.mediaId, ctx.favorite, ctx.playlistName);
    });
}

void RdNowPlaying::setFavorite(bool favorite)
{
    MediaLib* mediaLib = m_ctx ? m_ctx->getMediaLibrary() : nullptr;
    if (!mediaLib || m_mediaId <= 0 || favorite == m_favorite)
        return;

    const int64_t mediaId = m_mediaId;
    mediaLib->runOnMLThread(this, [mediaId, favorite](vlc_medialibrary_t* ml) {
        vlc_ml_media_set_favorite(ml, mediaId, favorite);
    });
    setLibraryValues(m_mediaId, favorite, m_playlistName);
}

void RdNowPlaying::setLibraryValues(int64_t mediaId, bool favorite, const QString& playlistName)
{
    if (mediaId == m_mediaId && favorite == m_favorite && playlistName == m_playlistName)
        return;
    m_mediaId = mediaId;
    m_favorite = favorite;
    m_playlistName = playlistName;
    emit libraryChanged();
}
