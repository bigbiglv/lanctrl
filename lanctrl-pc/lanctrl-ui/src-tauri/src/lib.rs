mod features;
pub mod network;
mod peripherals;
mod scheduler;
pub mod store;
mod web_console;

use crate::network::server::{
    cleanup_stale_presence, disconnect_client_session, get_clients_with_status,
    notify_mobile_disconnect, ping_mobile_device, SessionEvent,
};
use mdns_sd::ServiceDaemon;
use serde::Serialize;
use std::sync::Mutex;
use std::time::Duration;
use tauri::{Emitter, Manager, State};
use tokio::time::MissedTickBehavior;

#[derive(Default)]
struct MdnsRuntime {
    daemon: Mutex<Option<ServiceDaemon>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MdnsStatus {
    enabled: bool,
}

fn current_mdns_enabled() -> bool {
    let store = store::GLOBAL_STORE.lock().unwrap();
    store.data.mdns_enabled
}

fn apply_mdns_enabled(
    runtime: &MdnsRuntime,
    device_id: &str,
    device_name: &str,
    enabled: bool,
) -> Result<(), String> {
    if enabled {
        let mut daemon = runtime.daemon.lock().unwrap();
        if daemon.is_some() {
            return Ok(());
        }

        let next = network::mdns::start_mdns(device_id, device_name, 3000)
            .map_err(|error| error.to_string())?;
        *daemon = Some(next);
        return Ok(());
    }

    let existing = {
        let mut daemon = runtime.daemon.lock().unwrap();
        daemon.take()
    };

    if let Some(existing) = existing {
        network::mdns::stop_mdns(existing).map_err(|error| error.to_string())?;
    }

    Ok(())
}

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
fn get_pending_tasks() -> Vec<lanctrl_scheduler::ScheduledTask> {
    scheduler::list_tasks()
}

#[tauri::command]
fn get_task_history_entries() -> Vec<store::TaskHistoryEntry> {
    scheduler::list_task_history()
}

#[tauri::command]
fn get_mdns_status() -> MdnsStatus {
    MdnsStatus {
        enabled: current_mdns_enabled(),
    }
}

#[tauri::command]
fn set_mdns_enabled(
    app: tauri::AppHandle,
    runtime: State<MdnsRuntime>,
    enabled: bool,
) -> Result<MdnsStatus, String> {
    let (device_id, device_name) = {
        let mut store = store::GLOBAL_STORE.lock().unwrap();
        store.set_mdns_enabled(enabled);
        (store.data.device_id.clone(), store.data.device_name.clone())
    };

    apply_mdns_enabled(runtime.inner(), &device_id, &device_name, enabled)?;
    let status = MdnsStatus { enabled };
    let _ = app.emit("mdns_status_changed", &status);
    Ok(status)
}

#[tauri::command]
fn remove_paired_client(app: tauri::AppHandle, client_id: String) -> Result<(), String> {
    let disconnected_event = {
        let store = store::GLOBAL_STORE.lock().unwrap();
        store
            .data
            .paired_clients
            .get(&client_id)
            .map(|client| SessionEvent {
                client_id: client.client_id.clone(),
                client_name: client.client_name.clone(),
            })
    };

    disconnect_client_session(&client_id, "PC 已移除设备授权");

    let mut store = store::GLOBAL_STORE.lock().unwrap();
    store.remove_paired_client(&client_id);
    drop(store);

    network::server::ACTIVE_CONNECTIONS
        .lock()
        .unwrap()
        .remove(&client_id);
    network::server::ONLINE_CLIENTS
        .lock()
        .unwrap()
        .remove(&client_id);
    network::server::LAST_HEARTBEATS
        .lock()
        .unwrap()
        .remove(&client_id);

    if let Some(event) = disconnected_event {
        let _ = app.emit("device_disconnected", event);
    }
    let _ = app.emit("paired_clients_changed", serde_json::json!({}));
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(peripherals::init_state())
        .manage(MdnsRuntime::default())
        .invoke_handler(tauri::generate_handler![
            peripherals::get_peripheral_devices,
            peripherals::start_device_watch,
            peripherals::stop_device_watch,
            features::get_feature_groups,
            features::get_feature_snapshot,
            features::execute_feature_command,
            resolve_pair_request,
            get_clients_with_status,
            get_pending_tasks,
            get_task_history_entries,
            get_mdns_status,
            set_mdns_enabled,
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

            if let Ok(app_dir) = app.path().app_data_dir() {
                store::init_store(app_dir);
            }

            scheduler::init(&app.handle().clone());

            let (device_id, device_name, mdns_enabled) = {
                let store = store::GLOBAL_STORE.lock().unwrap();
                (
                    store.data.device_id.clone(),
                    store.data.device_name.clone(),
                    store.data.mdns_enabled,
                )
            };

            let tauri_app = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                network::server::start_server(3000, tauri_app).await;
            });

            let cleanup_app = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(Duration::from_secs(5));
                interval.set_missed_tick_behavior(MissedTickBehavior::Skip);

                loop {
                    interval.tick().await;
                    cleanup_stale_presence(&cleanup_app, 20_000);
                }
            });

            if mdns_enabled {
                let runtime = app.state::<MdnsRuntime>();
                apply_mdns_enabled(runtime.inner(), &device_id, &device_name, true)?;
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
