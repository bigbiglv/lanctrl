use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;

pub fn start_mdns(device_id: &str, device_name: &str, port: u16) -> Result<ServiceDaemon, Box<dyn std::error::Error>> {
    let mdns = ServiceDaemon::new()?;
    let service_type = "_lanctrl._tcp.local.";
    let instance_name = device_name;
    let host_name = format!("{}.local.", device_id);

    let mut properties = HashMap::new();
    properties.insert("deviceId".to_string(), device_id.to_string());
    properties.insert("deviceName".to_string(), device_name.to_string());

    let my_service = ServiceInfo::new(
        service_type,
        instance_name,
        &host_name,
        "", // 传空字符串在 mdns-sd 中会自动选择合适的接口进行多播广播
        port,
        Some(properties),
    )?;

    mdns.register(my_service)?;
    println!("Started mDNS broadcast: {} on port {}", service_type, port);
    log::info!("Started mDNS broadcast: {} on port {}", service_type, port);

    Ok(mdns)
}
