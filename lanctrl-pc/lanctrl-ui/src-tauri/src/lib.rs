mod features;
pub mod network;
mod peripherals;
pub mod store;

use crate::network::server::{
    get_clients_with_status, notify_mobile_disconnect, ping_mobile_device,
};
use tauri::Manager;

#[tauri::command]
async fn resolve_pair_request(client_id: String, allowed: bool) -> Result<(), String> {
    let mut map = network::server::PENDING_REQUESTS.lock().unwrap();
    if let Some(tx) = map.remove(&client_id) {
        let _ = tx.send(allowed);
        Ok(())
    } else {
        Err("No pending request found".into())
    }
}

#[tauri::command]
fn remove_paired_client(client_id: String) -> Result<(), String> {
    let mut store = store::GLOBAL_STORE.lock().unwrap();
    store.remove_paired_client(&client_id);
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(peripherals::init_state())
        .invoke_handler(tauri::generate_handler![
            peripherals::get_peripheral_devices,
            peripherals::start_device_watch,
            peripherals::stop_device_watch,
            features::get_feature_groups,
            features::get_feature_snapshot,
            features::execute_feature_command,
            resolve_pair_request,
            get_clients_with_status,
            remove_paired_client,
            ping_mobile_device,
            notify_mobile_disconnect
        ])
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }

            // 初始化配置持久化存放地址
            if let Ok(app_dir) = app.path().app_data_dir() {
                store::init_store(app_dir);
            }

            let (device_id, device_name) = {
                let s = store::GLOBAL_STORE.lock().unwrap();
                (s.data.device_id.clone(), s.data.device_name.clone())
            };

            let tauri_app = app.handle().clone();

            tauri::async_runtime::spawn(async move {
                network::server::start_server(3000, tauri_app).await;
            });

            if let Ok(mdns) = network::mdns::start_mdns(&device_id, &device_name, 3000) {
                app.manage(mdns); // 存入 managed state 保持其生命周期不被释放
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
