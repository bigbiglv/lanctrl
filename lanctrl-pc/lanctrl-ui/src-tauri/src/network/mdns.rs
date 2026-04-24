use if_addrs::{get_if_addrs, IfAddr};
use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr};

fn sanitize_host_label(value: &str) -> String {
    let mut label = value
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>();

    while label.contains("--") {
        label = label.replace("--", "-");
    }

    label.trim_matches('-').to_string()
}

fn collect_broadcast_ips() -> Result<Vec<IpAddr>, Box<dyn std::error::Error>> {
    let addresses = get_if_addrs()?
        .into_iter()
        .filter_map(|interface| match interface.addr {
            IfAddr::V4(ipv4) if !ipv4.ip.is_loopback() && !ipv4.ip.is_link_local() => {
                Some(IpAddr::V4(Ipv4Addr::new(
                    ipv4.ip.octets()[0],
                    ipv4.ip.octets()[1],
                    ipv4.ip.octets()[2],
                    ipv4.ip.octets()[3],
                )))
            }
            _ => None,
        })
        .collect::<Vec<_>>();

    if addresses.is_empty() {
        return Err("no non-loopback IPv4 address found for mDNS broadcast".into());
    }

    Ok(addresses)
}

pub fn start_mdns(
    device_id: &str,
    device_name: &str,
    port: u16,
) -> Result<ServiceDaemon, Box<dyn std::error::Error>> {
    let mdns = ServiceDaemon::new()?;
    let service_type = "_lanctrl._tcp.local.";
    let instance_name = device_name;
    let host_label = sanitize_host_label(device_name);
    let short_device_id = device_id.chars().take(8).collect::<String>();
    let host_name = if host_label.is_empty() {
        format!("lanctrl-pc-{}.local.", short_device_id)
    } else {
        format!("{}-{}.local.", host_label, short_device_id)
    };
    let ip_addresses = collect_broadcast_ips()?;

    let mut properties = HashMap::new();
    properties.insert("deviceId".to_string(), device_id.to_string());
    properties.insert("deviceName".to_string(), device_name.to_string());

    let service = ServiceInfo::new(
        service_type,
        instance_name,
        &host_name,
        &ip_addresses[..],
        port,
        Some(properties),
    )?
    .enable_addr_auto();

    mdns.register(service)?;
    log::info!(
        "Started mDNS broadcast: {} on port {}, host {}, addresses {:?}",
        service_type,
        port,
        host_name,
        ip_addresses
    );

    Ok(mdns)
}

pub fn stop_mdns(mdns: ServiceDaemon) -> Result<(), Box<dyn std::error::Error>> {
    let receiver = mdns.shutdown()?;
    let _ = receiver.recv();
    Ok(())
}
