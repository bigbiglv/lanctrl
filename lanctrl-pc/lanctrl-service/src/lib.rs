use std::fmt::{Display, Formatter};

use lanctrl_control::system;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureGroup {
    pub group_key: String,
    pub title: String,
    pub description: String,
    pub features: Vec<FeatureDefinition>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureDefinition {
    pub feature_key: String,
    pub title: String,
    pub description: String,
    pub mobile_ready: bool,
    pub control: FeatureControl,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum FeatureControl {
    Action {
        button_text: String,
        tone: FeatureTone,
        confirm_required: bool,
    },
    Range {
        min: u8,
        max: u8,
        step: u8,
        unit: String,
        action_text: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FeatureTone {
    Primary,
    Danger,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureSnapshot {
    pub volume_level: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "feature", rename_all = "snake_case")]
pub enum FeatureCommand {
    Shutdown,
    Restart,
    TestNotification,
    ErrorTest,
    Volume { level: u8 },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureExecutionResult {
    pub feature_key: String,
    pub message: String,
    pub volume_level: Option<u8>,
}

#[derive(Debug)]
pub struct FeatureServiceError {
    message: String,
}

impl FeatureServiceError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl Display for FeatureServiceError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for FeatureServiceError {}

impl From<system::SystemControlError> for FeatureServiceError {
    fn from(value: system::SystemControlError) -> Self {
        Self::new(value.to_string())
    }
}

pub fn get_feature_groups() -> Vec<FeatureGroup> {
    vec![
        FeatureGroup {
            group_key: "power".into(),
            title: "电源控制".into(),
            description: "执行高风险系统操作前，前端和移动端都应做显式确认。".into(),
            features: vec![
                FeatureDefinition {
                    feature_key: "shutdown".into(),
                    title: "关机".into(),
                    description: "立即关闭当前电脑。".into(),
                    mobile_ready: true,
                    control: FeatureControl::Action {
                        button_text: "立即关机".into(),
                        tone: FeatureTone::Danger,
                        confirm_required: true,
                    },
                },
                FeatureDefinition {
                    feature_key: "restart".into(),
                    title: "重启".into(),
                    description: "立即重启当前电脑。".into(),
                    mobile_ready: true,
                    control: FeatureControl::Action {
                        button_text: "立即重启".into(),
                        tone: FeatureTone::Danger,
                        confirm_required: true,
                    },
                },
                FeatureDefinition {
                    feature_key: "test_notification".into(),
                    title: "测试提示".into(),
                    description: "弹出一条提示，用于验证即时执行和定时任务链路。".into(),
                    mobile_ready: true,
                    control: FeatureControl::Action {
                        button_text: "测试提示".into(),
                        tone: FeatureTone::Primary,
                        confirm_required: false,
                    },
                },
                FeatureDefinition {
                    feature_key: "error_test".into(),
                    title: "错误测试提示".into(),
                    description: "3 秒后返回测试错误，用于查看 Web 错误提示和失败历史。".into(),
                    mobile_ready: true,
                    control: FeatureControl::Action {
                        button_text: "测试报错".into(),
                        tone: FeatureTone::Primary,
                        confirm_required: false,
                    },
                },
            ],
        },
        FeatureGroup {
            group_key: "audio".into(),
            title: "音频控制".into(),
            description: "统一使用 0 到 100 的音量范围，便于前端与移动端复用。".into(),
            features: vec![FeatureDefinition {
                feature_key: "volume".into(),
                title: "音量调整".into(),
                description: "读取并设置系统主音量。".into(),
                mobile_ready: true,
                control: FeatureControl::Range {
                    min: 0,
                    max: 100,
                    step: 1,
                    unit: "%".into(),
                    action_text: "应用音量".into(),
                },
            }],
        },
    ]
}

pub fn get_feature_snapshot() -> Result<FeatureSnapshot, FeatureServiceError> {
    Ok(FeatureSnapshot {
        volume_level: system::get_system_volume()?,
    })
}

pub fn execute_feature_command(
    command: FeatureCommand,
) -> Result<FeatureExecutionResult, FeatureServiceError> {
    match command {
        FeatureCommand::Shutdown => {
            system::shutdown()?;
            Ok(FeatureExecutionResult {
                feature_key: "shutdown".into(),
                message: "关机指令已发送。".into(),
                volume_level: None,
            })
        }
        FeatureCommand::Restart => {
            system::restart()?;
            Ok(FeatureExecutionResult {
                feature_key: "restart".into(),
                message: "重启指令已发送。".into(),
                volume_level: None,
            })
        }
        FeatureCommand::TestNotification => Ok(FeatureExecutionResult {
            feature_key: "test_notification".into(),
            message: "测试提示已触发。".into(),
            volume_level: None,
        }),
        FeatureCommand::ErrorTest => {
            std::thread::sleep(std::time::Duration::from_secs(3));
            Err(FeatureServiceError::new(
                "错误测试提示：PC 端执行 3 秒后返回测试错误。",
            ))
        }
        FeatureCommand::Volume { level } => {
            let applied_level = system::set_system_volume(level)?;
            Ok(FeatureExecutionResult {
                feature_key: "volume".into(),
                message: format!("系统音量已调整到 {applied_level}%"),
                volume_level: Some(applied_level),
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{get_feature_groups, FeatureCommand};

    #[test]
    fn feature_catalog_should_expose_mobile_ready_features() {
        let groups = get_feature_groups();
        let feature_keys = groups
            .iter()
            .flat_map(|group| group.features.iter())
            .map(|feature| feature.feature_key.as_str())
            .collect::<Vec<_>>();

        assert!(feature_keys.contains(&"shutdown"));
        assert!(feature_keys.contains(&"restart"));
        assert!(feature_keys.contains(&"test_notification"));
        assert!(feature_keys.contains(&"error_test"));
        assert!(feature_keys.contains(&"volume"));
        assert!(groups
            .iter()
            .flat_map(|group| group.features.iter())
            .all(|feature| feature.mobile_ready));
    }

    #[test]
    fn volume_command_should_keep_requested_level() {
        let command = FeatureCommand::Volume { level: 42 };

        match command {
            FeatureCommand::Volume { level } => assert_eq!(level, 42),
            _ => panic!("unexpected command variant"),
        }
    }
}
