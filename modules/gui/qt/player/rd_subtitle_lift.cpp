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

#include "rd_subtitle_lift.hpp"

#include <algorithm>
#include <cstdio>
#include <cstdlib>

#include <vlc_player.h>
#include <vlc_vout.h>

#include "player/input_models.hpp"
#include "player/player_controller.hpp"
#include "util/varchoicemodel.hpp"

RdSubtitleLift::RdSubtitleLift(PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_player(player)
{
    // a new video output starts without the lift
    connect(m_player, &PlayerController::voutListChanged, this, [this]() {
        apply();
        updatePictureAspect();
    });
    connect(m_player, &PlayerController::inputChanged, this, &RdSubtitleLift::updatePictureAspect);

    // the picture's shape: the video track (its size is known once it is decoded, and the
    // selection can change) and the forced aspect ratio
    TrackListModel* videoTracks = m_player->getVideoTracks();
    connect(videoTracks, &QAbstractItemModel::dataChanged, this, &RdSubtitleLift::updatePictureAspect);
    connect(videoTracks, &QAbstractItemModel::rowsInserted, this, &RdSubtitleLift::updatePictureAspect);
    connect(videoTracks, &QAbstractItemModel::rowsRemoved, this, &RdSubtitleLift::updatePictureAspect);
    connect(videoTracks, &QAbstractItemModel::modelReset, this, &RdSubtitleLift::updatePictureAspect);
    VLCVarChoiceModel* aspectRatio = m_player->getAspectRatio();
    connect(aspectRatio, &QAbstractItemModel::dataChanged, this, &RdSubtitleLift::updatePictureAspect);
    connect(aspectRatio, &QAbstractItemModel::modelReset, this, &RdSubtitleLift::updatePictureAspect);

    updatePictureAspect();
}

void RdSubtitleLift::setLift(int lift)
{
    lift = std::max(0, lift);
    if (lift == m_lift)
        return;
    m_lift = lift;
    apply();
    emit liftChanged();
}

void RdSubtitleLift::apply()
{
    for (const SharedVOutThread& vout : m_player->getVouts())
        var_SetInteger(vout.get(), "sub-ui-margin", m_lift);
}

void RdSubtitleLift::updatePictureAspect()
{
    double aspect = 0.;

    // a forced aspect ratio ("16:9", "2.35:1") wins over the video's own
    const PlayerController::VOutThreadList vouts = m_player->getVouts();
    if (!vouts.isEmpty())
    {
        char* forced = var_GetNonEmptyString(vouts.first().get(), "aspect-ratio");
        if (forced)
        {
            double num = 0., den = 0.;
            if (std::sscanf(forced, "%lf:%lf", &num, &den) == 2 && num > 0. && den > 0.)
                aspect = num / den;
            free(forced);
        }
    }

    if (aspect <= 0.)
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker locker{ player };
        const vlc_player_track* track = vlc_player_GetSelectedTrack(player, VIDEO_ES);
        if (track)
        {
            const video_format_t& fmt = track->fmt.video;
            const unsigned width = fmt.i_visible_width ? fmt.i_visible_width : fmt.i_width;
            const unsigned height = fmt.i_visible_height ? fmt.i_visible_height : fmt.i_height;
            if (width > 0 && height > 0)
            {
                const double sar = (fmt.i_sar_num && fmt.i_sar_den)
                                       ? double(fmt.i_sar_num) / fmt.i_sar_den : 1.;
                aspect = width * sar / height;
                if (ORIENT_IS_SWAP(fmt.orientation))
                    aspect = 1. / aspect;
            }
        }
    }

    if (aspect == m_pictureAspect)
        return;
    m_pictureAspect = aspect;
    emit pictureAspectChanged();
}
