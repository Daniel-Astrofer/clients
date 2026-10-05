// SPDX-FileCopyrightText: 2023 Foundation Devices Inc.
// SPDX-FileCopyrightText: 2024 Foundation Devices Inc.
//
// SPDX-License-Identifier: MIT

use crate::error::update_last_error;
use arti::proxy;
use arti_client::config::CfgPath;
use arti_client::{DormantMode, HasKind, IntoTorAddr, StreamPrefs, TorClient, TorClientConfig};
use lazy_static::lazy_static;
use std::error::Error;
use std::ffi::{c_char, c_void, CStr};
use std::{io, ptr};
use tokio::runtime::{Builder, Runtime};
use tokio::task::JoinHandle;
use tor_config::Listen;
use tor_rtcompat::tokio::TokioNativeTlsRuntime;
use tor_rtcompat::ToplevelBlockOn;

pub use crate::error::tor_last_error_message;
#[cfg(not(target_os = "windows"))]
pub use crate::util::tor_get_nofile_limit;
#[cfg(not(target_os = "windows"))]
pub use crate::util::tor_set_nofile_limit;

#[macro_use]
mod error;
mod util;

lazy_static! {
    static ref RUNTIME: io::Result<Runtime> = Builder::new_multi_thread().enable_all().build();
}

#[repr(C)]
pub struct Tor {
    client: *mut c_void,
    proxy: *mut c_void,
}

#[no_mangle]
pub unsafe extern "C" fn tor_start(
    socks_port: u16,
    state_dir: *const c_char,
    cache_dir: *const c_char,
) -> Tor {
    let err_ret = Tor {
        client: ptr::null_mut(),
        proxy: ptr::null_mut(),
    };

    let state_dir = unwrap_or_return!(CStr::from_ptr(state_dir).to_str(), err_ret);
    let cache_dir = unwrap_or_return!(CStr::from_ptr(cache_dir).to_str(), err_ret);

    let runtime = unwrap_or_return!(TokioNativeTlsRuntime::create(), err_ret);

    let mut cfg_builder = TorClientConfig::builder();
    cfg_builder
        .storage()
        .state_dir(CfgPath::new(state_dir.to_owned()))
        .cache_dir(CfgPath::new(cache_dir.to_owned()));
    cfg_builder.address_filter().allow_onion_addrs(true);

    let cfg = unwrap_or_return!(cfg_builder.build(), err_ret);

    let client = unwrap_or_return!(
        runtime.block_on(async {
            TorClient::with_runtime(runtime.clone())
                .config(cfg)
                .create_bootstrapped()
                .await
        }),
        err_ret
    );

    let proxy_handle_box = Box::new(start_proxy(socks_port, client.clone()));
    let client_box = Box::new(client.clone());

    Tor {
        client: Box::into_raw(client_box) as *mut c_void,
        proxy: Box::into_raw(proxy_handle_box) as *mut c_void,
    }
}

#[no_mangle]
pub unsafe extern "C" fn tor_client_bootstrap(client: *mut c_void) -> bool {
    // Return false if client is null (not started)
    if client.is_null() {
        return false;
    }

    let client = &*(client as *mut TorClient<TokioNativeTlsRuntime>);

    unwrap_or_return!(client.runtime().block_on(client.bootstrap()), false);
    true
}

#[no_mangle]
pub unsafe extern "C" fn tor_client_check_connect(
    client: *mut c_void,
    target_host: *const c_char,
    target_port: u16,
) -> bool {
    if client.is_null() {
        update_last_error(io::Error::new(io::ErrorKind::Other, "Tor client is null"));
        return false;
    }

    let target_host = unwrap_or_return!(CStr::from_ptr(target_host).to_str(), false);
    let client = &*(client as *mut TorClient<TokioNativeTlsRuntime>);
    let target = unwrap_or_return!((target_host.to_owned(), target_port).into_tor_addr(), false);

    let mut prefs = StreamPrefs::new();
    prefs.ipv4_only();
    if target_host.to_ascii_lowercase().ends_with(".onion") {
        prefs.connect_to_onion_services(tor_config::BoolOrAuto::Explicit(true));
    }

    match client
        .runtime()
        .block_on(client.connect_with_prefs(&target, &prefs))
    {
        Ok(_stream) => true,
        Err(error) => {
            let mut message = format!(
                "Tor direct connect to {}:{} failed: {:?}: {}",
                target_host,
                target_port,
                error.kind(),
                error
            );
            let mut cause = error.source();
            while let Some(parent) = cause {
                message.push_str(&format!("; caused by: {}", parent));
                cause = parent.source();
            }
            update_last_error(io::Error::new(io::ErrorKind::Other, message));
            false
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn tor_client_set_dormant(client: *mut c_void, soft_mode: bool) {
    // Return early if client is null (not started)
    if client.is_null() {
        return;
    }

    let client = &*(client as *mut TorClient<TokioNativeTlsRuntime>);

    let dormant_mode = if soft_mode {
        DormantMode::Soft
    } else {
        DormantMode::Normal
    };
    client.set_dormant(dormant_mode);
}

#[no_mangle]
pub unsafe extern "C" fn tor_proxy_stop(proxy: *mut c_void) {
    // Return early if proxy is null (already stopped or never started)
    if proxy.is_null() {
        return;
    }

    let proxy = Box::from_raw(proxy as *mut JoinHandle<anyhow::Result<()>>);
    proxy.abort();
}

fn start_proxy(
    port: u16,
    client: TorClient<TokioNativeTlsRuntime>,
) -> JoinHandle<anyhow::Result<()>> {
    println!("Starting proxy!");
    let rt = RUNTIME.as_ref().unwrap();
    rt.spawn(proxy::run_proxy(
        client.runtime().clone(),
        client.clone(),
        Listen::new_localhost(port),
        None,
    ))
}

// Due to its simple signature this dummy function is the one added (unused) to iOS swift codebase to force Xcode to link the lib
#[no_mangle]
pub unsafe extern "C" fn tor_hello() {
    println!("HELLO THERE");
}
