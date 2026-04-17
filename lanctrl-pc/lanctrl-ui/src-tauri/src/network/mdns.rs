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
        "0.0.0.0", // 依靠路由多组播自动抓包网卡地址
        port,
        Some(properties),
    )?;
    
    mdns.register(my_service)?;
    log::info!("Started mDNS broadcast: {} on port {}", service_type, port);
    
    Ok(mdns)
}
