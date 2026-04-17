use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PairedClient {
    pub client_id: String,
    pub client_name: String,
    pub token_hash: String,
    pub last_seen_at: u64,
    #[serde(default)]
    pub last_ip: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    pub device_id: String,
    pub device_name: String,
    pub paired_clients: HashMap<String, PairedClient>,
}

impl Default for AppConfig {
    fn default() -> Self {
        // 跨平台获取设备名兜底策略
        let hostname = std::env::var("COMPUTERNAME")
            .or_else(|_| std::env::var("USER"))
            .unwrap_or_else(|_| "LanCtrl-PC".to_string());
            
        Self {
            device_id: Uuid::new_v4().to_string(),
            device_name: hostname,
            paired_clients: HashMap::new(),
        }
    }
}

lazy_static! {
    pub static ref GLOBAL_STORE: Arc<Mutex<Store>> = Arc::new(Mutex::new(Store::new(None)));
}

pub fn init_store(app_data_dir: PathBuf) {
    let config_file = app_data_dir.join("devices.json");
    let mut store = GLOBAL_STORE.lock().unwrap();
    store.set_path(config_file);
}

pub struct Store {
    pub config_path: Option<PathBuf>,
    pub data: AppConfig,
}

impl Store {
    pub fn new(path: Option<PathBuf>) -> Self {
        let mut store = Self {
            config_path: path,
            data: AppConfig::default(),
        };
        store.load();
        store
    }

    pub fn set_path(&mut self, path: PathBuf) {
        self.config_path = Some(path);
        self.load();
    }

    pub fn load(&mut self) -> bool {
        if let Some(path) = &self.config_path {
            if path.exists() {
                if let Ok(content) = fs::read_to_string(path) {
                    // 若存在，且解析成功，覆盖掉默认初始化的配置
                    if let Ok(config) = serde_json::from_str::<AppConfig>(&content) {
                        self.data = config;
                        return true;
                    }
                }
            }
        }
        // 如果不存在配置文件则强制走一次写入保存
        self.save();
        false
    }

    pub fn save(&self) -> bool {
        if let Some(path) = &self.config_path {
            if let Some(parent) = path.parent() {
                let _ = fs::create_dir_all(parent);
            }
            if let Ok(content) = serde_json::to_string_pretty(&self.data) {
                return fs::write(path, content).is_ok();
            }
        }
        false
    }

    // Auth actions
    pub fn is_client_paired(&self, client_id: &str, token_hash: &str) -> bool {
        if let Some(client) = self.data.paired_clients.get(client_id) {
            return client.token_hash == token_hash;
        }
        false
    }

    pub fn add_paired_client(&mut self, client: PairedClient) {
        self.data.paired_clients.insert(client.client_id.clone(), client);
        self.save();
    }

    pub fn remove_paired_client(&mut self, client_id: &str) {
        self.data.paired_clients.remove(client_id);
        self.save();
    }
}
