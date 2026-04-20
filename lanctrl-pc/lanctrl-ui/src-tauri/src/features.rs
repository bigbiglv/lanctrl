use lanctrl_service::{
    execute_feature_command as dispatch_feature_command, get_feature_groups as load_feature_groups,
    get_feature_snapshot as load_feature_snapshot, FeatureCommand, FeatureExecutionResult,
    FeatureGroup, FeatureSnapshot,
};

#[tauri::command]
pub fn get_feature_groups() -> Result<Vec<FeatureGroup>, String> {
    Ok(load_feature_groups())
}

#[tauri::command]
pub fn get_feature_snapshot() -> Result<FeatureSnapshot, String> {
    load_feature_snapshot().map_err(|error| error.to_string())
}

#[tauri::command]
pub fn execute_feature_command(command: FeatureCommand) -> Result<FeatureExecutionResult, String> {
    dispatch_feature_command(command).map_err(|error| error.to_string())
}
