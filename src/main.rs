use anyhow::Result;
use lapce_plugin::{
    psp_types::{
        lsp_types::{
            request::Initialize, DocumentFilter, DocumentSelector, InitializeParams, MessageType,
            Url,
        },
        Request,
    },
    register_plugin, LapcePlugin, PLUGIN_RPC,
};
use serde_json::Value;

#[derive(Default)]
struct State {}
register_plugin!(State);

fn initialize(params: InitializeParams) -> Result<()> {
    let document_selector: DocumentSelector = vec![
        // something is broken here
        DocumentFilter {
            language: None, // This alone doesn't work, should be with pattern
            pattern: Some(String::from("**/*.nix")),
            scheme: None,
        },
        DocumentFilter {
            language: Some(String::from("nix")),
            pattern: None,
            scheme: None,
        },
    ];

    let server_path = params
        .initialization_options
        .as_ref()
        .and_then(|options| options.get("lsp-path"))
        .and_then(|server_path| server_path.as_str())
        .and_then(|server_path| Url::parse(&format!("urn:{}", server_path)).ok());

    match server_path {
        Some(server_path) => {
            PLUGIN_RPC.start_lsp(
                server_path,
                Vec::new(),
                document_selector.clone(),
                None, // params.initialization_options,
            );
        }
        None => {
            PLUGIN_RPC.window_show_message(
                MessageType::ERROR,
                format!(
                    "Server binary couldn't be loaded, please check if it's installed and path is correct."
                ),
            );
        }
    }

    Ok(())
}

impl LapcePlugin for State {
    fn handle_request(&mut self, _id: u64, method: String, params: Value) {
        match method.as_str() {
            Initialize::METHOD => {
                let params: InitializeParams = serde_json::from_value(params).unwrap();
                let _ = initialize(params);
            }
            _ => {}
        }
    }
}
