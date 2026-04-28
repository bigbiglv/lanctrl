use std::fmt::{Display, Formatter};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

#[cfg(target_os = "windows")]
use windows::Media::Control::GlobalSystemMediaTransportControlsSession;
#[cfg(target_os = "windows")]
use windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus;
#[cfg(target_os = "windows")]
use windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager;

const APPLE_MUSIC_PROCESS_NAME: &str = "AppleMusic";

#[derive(Debug)]
pub enum MediaControlError {
    UnsupportedPlatform(&'static str),
    CommandFailed(String),
    SessionUnavailable,
    MediaApi(String),
}

impl Display for MediaControlError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnsupportedPlatform(message) => write!(f, "{message}"),
            Self::CommandFailed(message) => write!(f, "{message}"),
            Self::SessionUnavailable => write!(f, "Apple Music 尚未创建可控制的媒体会话"),
            Self::MediaApi(message) => write!(f, "{message}"),
        }
    }
}

impl std::error::Error for MediaControlError {}

#[derive(Debug, Clone, Copy)]
pub enum AppleMusicCommand {
    Previous,
    PlayPause,
    Next,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppleMusicPlaybackState {
    Playing,
    Paused,
    Stopped,
    Unavailable,
}

impl AppleMusicPlaybackState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Playing => "playing",
            Self::Paused => "paused",
            Self::Stopped => "stopped",
            Self::Unavailable => "unavailable",
        }
    }
}

pub fn is_apple_music_running() -> bool {
    #[cfg(target_os = "windows")]
    {
        let script = format!(
            "$p = Get-Process -Name '{}' -ErrorAction SilentlyContinue; if ($p) {{ exit 0 }} else {{ exit 1 }}",
            APPLE_MUSIC_PROCESS_NAME
        );

        Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", &script])
            .creation_flags(0x08000000)
            .status()
            .map(|status| status.success())
            .unwrap_or(false)
    }

    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

pub fn open_apple_music() -> Result<(), MediaControlError> {
    #[cfg(target_os = "windows")]
    {
        let mut command = Command::new("explorer.exe");
        command.arg("shell:AppsFolder\\AppleInc.AppleMusicWin_nzyj5cx40ttqa!App");
        command.creation_flags(0x08000000);

        let status = command
            .status()
            .map_err(|error| MediaControlError::CommandFailed(format!("打开 Apple Music 失败: {error}")))?;

        if status.success() {
            wait_for_apple_music_running(Duration::from_secs(5));
            Ok(())
        } else {
            Err(MediaControlError::CommandFailed(format!(
                "打开 Apple Music 失败，退出码: {:?}",
                status.code()
            )))
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        Err(MediaControlError::UnsupportedPlatform(
            "当前仅支持 Windows 版 Apple Music 控制",
        ))
    }
}

pub fn wait_for_apple_music_running(timeout: Duration) -> bool {
    let start = Instant::now();
    while start.elapsed() < timeout {
        if is_apple_music_running() {
            return true;
        }
        thread::sleep(Duration::from_millis(200));
    }

    is_apple_music_running()
}

pub fn execute_apple_music_command(command: AppleMusicCommand) -> Result<(), MediaControlError> {
    #[cfg(target_os = "windows")]
    {
        let session = find_apple_music_session()?;
        let accepted = match command {
            AppleMusicCommand::Previous => session
                .TrySkipPreviousAsync()
                .map_err(map_media_error)?
                .get()
                .map_err(map_media_error)?,
            AppleMusicCommand::PlayPause => session
                .TryTogglePlayPauseAsync()
                .map_err(map_media_error)?
                .get()
                .map_err(map_media_error)?,
            AppleMusicCommand::Next => session
                .TrySkipNextAsync()
                .map_err(map_media_error)?
                .get()
                .map_err(map_media_error)?,
        };

        if accepted {
            Ok(())
        } else {
            Err(MediaControlError::MediaApi(
                "Apple Music 未接受本次媒体控制请求".into(),
            ))
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        let _ = command;
        Err(MediaControlError::UnsupportedPlatform(
            "当前仅支持 Windows 版 Apple Music 控制",
        ))
    }
}

pub fn get_apple_music_playback_state() -> AppleMusicPlaybackState {
    #[cfg(target_os = "windows")]
    {
        let Ok(session) = find_apple_music_session() else {
            return AppleMusicPlaybackState::Unavailable;
        };
        let Ok(info) = session.GetPlaybackInfo() else {
            return AppleMusicPlaybackState::Unavailable;
        };
        let Ok(status) = info.PlaybackStatus() else {
            return AppleMusicPlaybackState::Unavailable;
        };

        match status {
            GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing => {
                AppleMusicPlaybackState::Playing
            }
            GlobalSystemMediaTransportControlsSessionPlaybackStatus::Paused => {
                AppleMusicPlaybackState::Paused
            }
            GlobalSystemMediaTransportControlsSessionPlaybackStatus::Stopped => {
                AppleMusicPlaybackState::Stopped
            }
            _ => AppleMusicPlaybackState::Unavailable,
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        AppleMusicPlaybackState::Unavailable
    }
}

#[cfg(target_os = "windows")]
fn find_apple_music_session() -> Result<GlobalSystemMediaTransportControlsSession, MediaControlError> {
    let manager = GlobalSystemMediaTransportControlsSessionManager::RequestAsync()
        .map_err(map_media_error)?
        .get()
        .map_err(map_media_error)?;
    let sessions = manager.GetSessions().map_err(map_media_error)?;
    let size = sessions.Size().map_err(map_media_error)?;

    for index in 0..size {
        let session = sessions.GetAt(index).map_err(map_media_error)?;
        let source = session
            .SourceAppUserModelId()
            .map_err(map_media_error)?
            .to_string();

        if source.to_ascii_lowercase().contains("applemusic") {
            return Ok(session);
        }
    }

    manager
        .GetCurrentSession()
        .ok()
        .and_then(|session| {
            session
                .SourceAppUserModelId()
                .ok()
                .map(|source| (session, source.to_string()))
        })
        .filter(|(_, source)| source.to_ascii_lowercase().contains("applemusic"))
        .map(|(session, _)| session)
        .ok_or(MediaControlError::SessionUnavailable)
}

#[cfg(target_os = "windows")]
fn map_media_error(error: windows::core::Error) -> MediaControlError {
    MediaControlError::MediaApi(error.to_string())
}
