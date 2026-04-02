#![allow(dead_code)]

use cent_jours_core::battle::{MapEdge, MapGraph, MapNode};
use rand::{rngs::StdRng, SeedableRng};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct CampaignMapData {
    nodes: Vec<MapNode>,
    edges: Vec<MapEdge>,
}

pub fn seeded_rng() -> StdRng {
    StdRng::seed_from_u64(42)
}

pub fn campaign_map() -> MapGraph {
    let data: CampaignMapData =
        serde_json::from_str(include_str!("../../../src/data/map_nodes.json"))
            .expect("map_nodes.json 应可解析");
    MapGraph::new(data.nodes, data.edges)
}

pub fn adjacent_pairs() -> Vec<(String, String)> {
    let data: CampaignMapData =
        serde_json::from_str(include_str!("../../../src/data/map_nodes.json"))
            .expect("map_nodes.json 应可解析");
    data.edges
        .into_iter()
        .map(|edge| (edge.from, edge.to))
        .collect()
}
