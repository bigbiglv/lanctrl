use axum::{
    extract::{ConnectInfo, State},
    routing::post,
    Json, Router,
};
use lanctrl_service::{
    execute_feature_command, get_feature_groups, get_feature_snapshot, FeatureCommand,
    FeatureExecutionResult, FeatureGroup, FeatureSnapshot,
};
use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use std::collections::HashMap as StdHashMap;
use std::collections::HashSet;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use tauri::AppHandle;
use tauri::Emitter;
use tokio::sync::oneshot;
use tower_http::cors::{Any, CorsLayer};
use uuid::Uuid;

use crate::store::{PairedClient, GLOBAL_STORE};

lazy_static! {
    pub static ref PENDING_REQUESTS: Arc<Mutex<StdHashMap<String, oneshot::Sender<bool>>>> = Arc::new(Mutex::new(StdHashMap::new()));
    /// 内存态：当前有效连接 (client_id 集合)，不需要持久化
    pub static ref ACTIVE_CONNECTIONS: Arc<Mutex<HashSet<String>>> = Arc::new(Mutex::new(HashSet::new()));
}

#[derive(Clone)]
pub struct AppState {
    pub tauri_app: AppHandle,
}

pub async fn start_server(port: u16, tauri_app: AppHandle) {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let state = AppState { tauri_app };

    let app = Router::new()
        .route("/auth/pair", post(auth_pair))
        .route("/auth/verify", post(auth_verify))
        .route("/auth/connect", post(auth_connect))
        .route("/auth/disconnect", post(auth_disconnect))
        .route("/features/catalog", post(features_catalog))
        .route("/features/execute", post(features_execute))
        .layer(cors)
        .with_state(state)
        .into_make_service_with_connect_info::<SocketAddr>();

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    log::info!("Axum server listening on {}", addr);

    if let Ok(listener) = tokio::net::TcpListener::bind(addr).await {
        tokio::spawn(async move {
            if let Err(e) = axum::serve(listener, app).await {
                log::error!("Axum server error: {}", e);
            }
        });
    } else {
        log::error!("Failed to bind Axum to port {}", port);
    }
}

#[derive(Deserialize, Serialize, Clone)]
pub struct PairRequestInfo {
    pub client_id: String,
    pub client_name: String,
}

#[derive(Serialize)]
pub struct PairResponse {
    pub success: bool,
    pub token: Option<String>,
    pub msg: String,
    pub device_id: Option<String>,
    pub device_name: Option<String>,
}

async fn auth_pair(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(payload): Json<PairRequestInfo>,
) -> Json<PairResponse> {
    let (tx, rx) = oneshot::channel();

    {
        let mut map = PENDING_REQUESTS.lock().unwrap();
        map.insert(payload.client_id.clone(), tx);
    }

    if let Err(e) = state.tauri_app.emit("pair_request", payload.clone()) {
        log::error!("Failed to emit event: {}", e);
        return Json(PairResponse {
            success: false,
            token: None,
            msg: "Internal server error".into(),
            device_id: None,
            device_name: None,
        });
    }

    match rx.await {
        Ok(allowed) => {
            if allowed {
                let token = Uuid::new_v4().to_string();

                let client = PairedClient {
                    client_id: payload.client_id,
                    client_name: payload.client_name,
                    token_hash: token.clone(),
                    last_seen_at: 0,
                    last_ip: Some(addr.ip().to_string()),
                };

                let (my_device_id, my_device_name) = {
                    let mut s = GLOBAL_STORE.lock().unwrap();
                    s.add_paired_client(client);
                    (s.data.device_id.clone(), s.data.device_name.clone())
                };

                Json(PairResponse {
                    success: true,
                    token: Some(token),
                    msg: "Pairing successful".into(),
                    device_id: Some(my_device_id),
                    device_name: Some(my_device_name),
                })
            } else {
                Json(PairResponse {
                    success: false,
                    token: None,
                    msg: "Pairing was denied by PC user".into(),
                    device_id: None,
                    device_name: None,
                })
            }
        }
        Err(_) => Json(PairResponse {
            success: false,
            token: None,
            msg: "Pairing request timed out or cancelled".into(),
            device_id: None,
            device_name: None,
        }),
    }
}

#[derive(Deserialize)]
pub struct VerifyRequest {
    pub client_id: String,
    pub token: String,
}

#[derive(Serialize)]
pub struct VerifyResponse {
    pub success: bool,
    pub msg: String,
}

fn is_client_authorized(client_id: &str, token: &str) -> bool {
    let store = GLOBAL_STORE.lock().unwrap();
    store.is_client_paired(client_id, token)
}

async fn auth_verify(
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(payload): Json<VerifyRequest>,
) -> Json<VerifyResponse> {
    let is_valid;
    {
        let mut store = GLOBAL_STORE.lock().unwrap();
        is_valid = store.is_client_paired(&payload.client_id, &payload.token);
        if is_valid {
            if let Some(client) = store
                .data
                .paired_clients
                .values_mut()
                .find(|c| c.client_id == payload.client_id)
            {
                client.last_ip = Some(addr.ip().to_string());
            }
            let _ = store.save();
        }
    }

    Json(VerifyResponse {
        success: is_valid,
        msg: if is_valid {
            "Verified"
        } else {
            "Invalid or missing token"
        }
        .into(),
    })
}

// ─── 连接/断开通知 ────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct SessionRequest {
    pub client_id: String,
    pub token: String,
}

#[derive(Serialize, Clone)]
pub struct SessionEvent {
    pub client_id: String,
    pub client_name: String,
}

async fn auth_connect(
    State(state): State<AppState>,
    Json(payload): Json<SessionRequest>,
) -> Json<serde_json::Value> {
    let store = GLOBAL_STORE.lock().unwrap();
    if !store.is_client_paired(&payload.client_id, &payload.token) {
        return Json(serde_json::json!({ "success": false, "msg": "Unauthorized" }));
    }
    let client_name = store
        .data
        .paired_clients
        .values()
        .find(|c| c.client_id == payload.client_id)
        .map(|c| c.client_name.clone())
        .unwrap_or_default();
    drop(store);

    ACTIVE_CONNECTIONS
        .lock()
        .unwrap()
        .insert(payload.client_id.clone());

    // 发送 Tauri 事件通知 Vue 前端
    let _ = state.tauri_app.emit(
        "device_connected",
        SessionEvent {
            client_id: payload.client_id,
            client_name,
        },
    );

    Json(serde_json::json!({ "success": true }))
}

#[derive(Deserialize)]
pub struct MobileFeatureCatalogRequest {
    pub client_id: String,
    pub token: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureCatalogResponse {
    pub success: bool,
    pub msg: String,
    pub groups: Vec<FeatureGroup>,
    pub snapshot: Option<FeatureSnapshot>,
}

#[derive(Deserialize)]
pub struct MobileFeatureExecuteRequest {
    pub client_id: String,
    pub token: String,
    #[serde(flatten)]
    pub command: FeatureCommand,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureExecuteResponse {
    pub success: bool,
    pub msg: String,
    pub result: Option<FeatureExecutionResult>,
}

async fn features_catalog(
    Json(payload): Json<MobileFeatureCatalogRequest>,
) -> Json<FeatureCatalogResponse> {
    if !is_client_authorized(&payload.client_id, &payload.token) {
        return Json(FeatureCatalogResponse {
            success: false,
            msg: "Unauthorized".into(),
            groups: vec![],
            snapshot: None,
        });
    }

    match get_feature_snapshot() {
        Ok(snapshot) => Json(FeatureCatalogResponse {
            success: true,
            msg: "OK".into(),
            groups: get_feature_groups(),
            snapshot: Some(snapshot),
        }),
        Err(error) => Json(FeatureCatalogResponse {
            success: false,
            msg: error.to_string(),
            groups: vec![],
            snapshot: None,
        }),
    }
}

async fn features_execute(
    Json(payload): Json<MobileFeatureExecuteRequest>,
) -> Json<FeatureExecuteResponse> {
    if !is_client_authorized(&payload.client_id, &payload.token) {
        return Json(FeatureExecuteResponse {
            success: false,
            msg: "Unauthorized".into(),
            result: None,
        });
    }

    match execute_feature_command(payload.command) {
        Ok(result) => Json(FeatureExecuteResponse {
            success: true,
            msg: result.message.clone(),
            result: Some(result),
        }),
        Err(error) => Json(FeatureExecuteResponse {
            success: false,
            msg: error.to_string(),
            result: None,
        }),
    }
}

async fn auth_disconnect(
    State(state): State<AppState>,
    Json(payload): Json<SessionRequest>,
) -> Json<serde_json::Value> {
    let store = GLOBAL_STORE.lock().unwrap();
    // 即使 Token 失效也允许断开（防止误删后残留状态）
    let client_name = store
        .data
        .paired_clients
        .values()
        .find(|c| c.client_id == payload.client_id)
        .map(|c| c.client_name.clone())
        .unwrap_or_else(|| "未知设备".to_string());
    drop(store);

    ACTIVE_CONNECTIONS
        .lock()
        .unwrap()
        .remove(&payload.client_id);

    let _ = state.tauri_app.emit(
        "device_disconnected",
        SessionEvent {
            client_id: payload.client_id,
            client_name,
        },
    );

    Json(serde_json::json!({ "success": true }))
}

// ─── Tauri Commands ───────────────────────────────────────────────

#[derive(Serialize, Clone)]
pub struct ClientInfo {
    pub client_id: String,
    pub client_name: String,
    pub last_seen_at: u64,
    pub last_ip: Option<String>,
    pub is_connected: bool, // 内存态，基于 ACTIVE_CONNECTIONS
}

#[tauri::command]
pub fn get_clients_with_status() -> Vec<ClientInfo> {
    let store = GLOBAL_STORE.lock().unwrap();
    let active = ACTIVE_CONNECTIONS.lock().unwrap();
    store
        .data
        .paired_clients
        .values()
        .map(|c| ClientInfo {
            client_id: c.client_id.clone(),
            client_name: c.client_name.clone(),
            last_seen_at: c.last_seen_at,
            last_ip: c.last_ip.clone(),
            is_connected: active.contains(&c.client_id),
        })
        .collect()
}

#[tauri::command]
pub async fn ping_mobile_device(ip: String) -> Result<bool, String> {
    let url = format!("http://{}:3001/ping", ip);
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(800))
        .build()
        .map_err(|e| e.to_string())?;

    match client.get(&url).send().await {
        Ok(res) => Ok(res.status().is_success()),
        Err(_) => Ok(false),
    }
}

/// 当 PC 端忘记/移除设备时，主动通知移动端断开
#[tauri::command]
pub async fn notify_mobile_disconnect(ip: String) -> Result<(), String> {
    let url = format!("http://{}:3001/disconnect", ip);
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(1000))
        .build()
        .map_err(|e| e.to_string())?;
    // 发出即走，不关心返回值
    let _ = client.post(&url).send().await;
    Ok(())
}
