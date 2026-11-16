/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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

#ifndef MODEL_RECOVERY_AGENT_HPP
#define MODEL_RECOVERY_AGENT_HPP

#include <QFile>
#include <QTimer>
#include <QSettings>
#include <QPointer>
#include <QFileInfo>
#include <QMessageBox>
#include <QTemporaryFile>
#include <QAbstractItemModel>
#include <QLockFile>

#include <cstdio>

#include "qt.hpp"

#include "dialogs/dialogs_provider.hpp"

class ModelRecoveryAgent
{
    const QPointer<QSettings> m_settings;
    const QString m_key;
    QString m_recoveryFileName;
    QTimer m_timer;
    bool m_conditionDismissInitialDirtiness = false;
    std::unique_ptr<QLockFile> m_lockFile;

public:
    // NOTE: settings and model must outlive the instance of this class.
    template<class T>
    ModelRecoveryAgent(class QSettings *settings, const QString& modelIdentifier, T* model)
        : m_settings(settings), m_key(modelIdentifier + QStringLiteral("/RecoveryFilePath"))
    {
        assert(settings);
        assert(model);
        settings->sync();
        if (settings->contains(m_key))
        {
            assert(settings->value(m_key).typeId() == QMetaType::QString);
            QString recoveryFileName = settings->value(m_key).toString();
            if (!recoveryFileName.isEmpty())
            {
                m_recoveryFileName = std::move(recoveryFileName);
                {
                    m_lockFile = std::make_unique<QLockFile>(m_recoveryFileName + QStringLiteral(".lock"));
                    m_lockFile->setStaleLockTime(0); // if the process crashed, QLockFile considers the lock stale regardless of the lock time
                    if (!m_lockFile->tryLock()) // if the older instance is still alive, it would have the lock
                        throw std::exception(); // Older instance is managing the recovery, don't take over. We don't support recovering multiple models at the moment.
                }
                const QFileInfo fileInfo(m_recoveryFileName);
                if (fileInfo.size() > 0)
                {
                    // redesign: the question runs an event loop of its own; a quit meanwhile
                    // deletes the model and the settings, and going on with them crashed
                    // (redesign/PERF_AUDIT_NOTES.md section 9)
                    const QPointer<T> modelAlive(model);
                    const QPointer<QSettings> settingsAlive(settings);
                    const int answer = DialogsProvider::getInstance()->messageDialog(qtr("Do you want to restore the %1 model from %2?").arg(modelIdentifier.toLower(),
                                                                                                                              fileInfo.lastModified().toString()),
                                                                      qtr("The application closed abruptly."),
                                                                      (QMessageBox::Yes | QMessageBox::No),
                                                                      QMessageBox::Yes,
                                                                      QMessageBox::Question);
                    if (!modelAlive || !settingsAlive)
                        throw std::exception(); // the interface is closing: the recovery file stays for the next start
                    if (answer == QMessageBox::Yes)
                    {
                        model->append(m_recoveryFileName);
                        m_conditionDismissInitialDirtiness = true;
                    }
                }
            }
        }

        if (m_recoveryFileName.isEmpty())
        {
            QTemporaryFile temporaryFile;
            temporaryFile.setAutoRemove(false);
            if (!temporaryFile.open())
                throw std::exception();
            m_recoveryFileName = temporaryFile.fileName();
            {
                assert(!m_lockFile);
                m_lockFile = std::make_unique<QLockFile>(m_recoveryFileName + QStringLiteral(".lock"));
                m_lockFile->setStaleLockTime(0); // if the process crashed, QLockFile considers the lock stale regardless of the lock time
                assert(!m_lockFile->isLocked()); // the file name is new here, it can not be locked before
                if (!m_lockFile->tryLock())
                    throw std::exception();
            }
            settings->setValue(m_key, m_recoveryFileName);
            settings->sync();
        }

        m_timer.setInterval(10000); // 10 seconds
        m_timer.setSingleShot(true);

        QObject::connect(&m_timer, &QTimer::timeout, model, [this, model]() {
            if (m_conditionDismissInitialDirtiness)
            {
                m_conditionDismissInitialDirtiness = false;
                return;
            }

            assert(!m_recoveryFileName.isEmpty());

            const QByteArray tmpFileName = (m_recoveryFileName + QStringLiteral(".part")).toLatin1();
            const QByteArray recoveryFileName = m_recoveryFileName.toLatin1();

            if (model->isEmpty())
            {
                remove(recoveryFileName.constData());
                return;
            }

            if (model->serialize(tmpFileName.constData()) != VLC_SUCCESS)
            {
                qDebug("playlist recovery: the playlist could not be written to %s", tmpFileName.constData());
                return;
            }

            remove(recoveryFileName.constData());
            if (rename(tmpFileName.constData(), recoveryFileName.constData()))
                qDebug("playlist recovery: %s could not be renamed to %s", tmpFileName.constData(),
                       recoveryFileName.constData());
            else
            {
                qDebug("playlist recovery: saved to %s", recoveryFileName.constData());
                assert(m_settings);
                m_settings->sync();
                if (!m_settings->contains(m_key))
                {
                    m_settings->setValue(m_key, m_recoveryFileName);
                    m_settings->sync();
                }
                else if (m_settings->value(m_key) != m_recoveryFileName)
                {
                    QObject::disconnect(model, nullptr, &m_timer, nullptr);
                    m_timer.stop();
                }
            }
        });

        // redesign: saved at most 10 s after the first change. Restarting the wait on every change
        // never saved a queue whose items keep being updated (the Windows smoke: the backup was
        // still empty after 60 s of playback, so a crash offered no restore)
        const auto changed = [this]() {
            if (!m_timer.isActive())
                m_timer.start();
        };
        QObject::connect(model, &T::itemsReset, &m_timer, changed);
        QObject::connect(model, &T::itemsAdded, &m_timer, changed);
        QObject::connect(model, &T::itemsMoved, &m_timer, changed);
        QObject::connect(model, &T::itemsRemoved, &m_timer, changed);
        QObject::connect(model, &T::itemsUpdated, &m_timer, changed);
    }

    // redesign: the interface quit while the restore question was open: nothing was answered, so
    // the recovery file and its setting stay and the question comes back at the next start; only
    // Yes or No clears them (redesign/PERF_AUDIT_NOTES.md section 9)
    void keepForNextStart()
    {
        m_timer.stop();
        m_recoveryFileName.clear();
    }

    ~ModelRecoveryAgent()
    {
        if (!m_recoveryFileName.isEmpty())
        {
            QFile::remove(m_recoveryFileName);
        }

        assert(m_settings);

        m_settings->sync();

        if (m_settings->value(m_key) == m_recoveryFileName)
        {
            m_settings->remove(m_key);
            m_settings->sync();
        }
    }
};

#endif // MODEL_RECOVERY_AGENT_HPP
